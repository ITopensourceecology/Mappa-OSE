=head1 NAME

RDF::Trine::Store::Redis - RDF Store for Redis

=head1 VERSION

This document describes RDF::Trine::Store::Redis version 0.137

=head1 SYNOPSIS

 use RDF::Trine::Store::Redis;

=head1 DESCRIPTION

RDF::Trine::Store::Redis provides a RDF::Trine::Store API to interact with a
Redis server.

=cut

package RDF::Trine::Store::Redis;

use strict;
use warnings;
no warnings 'redefine';
use base qw(RDF::Trine::Store);

use Redis;
use Cache::LRU;
use URI::Escape;
use Data::Dumper;
use List::Util qw(first);
use Scalar::Util qw(refaddr reftype blessed);
use HTTP::Request::Common ();
use JSON;

use RDF::Trine::Error qw(:try);

######################################################################

our $CACHING	= 1;

my @pos_names;
our $VERSION;
BEGIN {
	$VERSION	= "0.137";
	my $class	= __PACKAGE__;
	$RDF::Trine::Store::STORE_CLASSES{ $class }	= $VERSION;
	@pos_names	= qw(subject predicate object context);
}

######################################################################

=head1 METHODS

Beyond the methods documented below, this class inherits methods from the
L<RDF::Trine::Store> class.

=over 4

=item C<< new ( $server ) >>

Returns a new storage object.

=item C<new_with_config ( $hashref )>

Returns a new storage object configured with a hashref with certain
keys as arguments.

The C<storetype> key must be C<Redis> for this backend.

The following key must also be used:

=over

=item foo

description

=back

=cut

sub new {
	my $class	= shift;
	my %args	= @_;
	my $size	= delete $args{cache_size};
	$size		= 128 unless ($size > 0);
	my $r		= Redis->new( %args );
	my $cache	= Cache::LRU->new( size => $size );
	my $self	= bless({ conn => $r, cache => $cache, cache_size => $size }, $class);
	return $self;
}

=item C<< conn >>

Returns the Redis connection object.

=cut

sub conn {
	my $self	= shift;
	return $self->{conn};
}

=item C<< cache >>

Returns the Cache::LRU object used to cache frequently used redis data.

=cut

sub cache {
	my $self	= shift;
	return $self->{cache};
}

sub _new_with_string {
	my $class	= shift;
	my $config	= shift;
	return $class->new( $config );
}

=item C<< new_with_config ( \%config ) >>

Returns a new RDF::Trine::Store object based on the supplied configuration hashref.

=cut

sub new_with_config {
	my $proto	= shift;
	my $config	= shift;
	$config->{storetype}	= 'Redis';
	return $proto->SUPER::new_with_config( $config );
}

sub _new_with_config {
	my $class	= shift;
	my $config	= shift;
	return $class->new( server => $config->{server}, cache_size => $config->{cache_size} );
}

sub _config_meta {
	return {
		required_keys	=> [],
		fields			=> {
			server		=> { description => 'server', type => 'string' },
			cache_size	=> { description => 'cache size', type => 'int' },
		}
	}
}

sub _id_node {
	my $self	= shift;
	my $id		= shift;
	my $r		= $self->conn;
	my $p		= RDF::Trine::Parser::NTriples->new();
	my $valkey	= "RT:node.value.$id";
	my $str;
if ($CACHING) {
	$str		= $self->cache->get($valkey);
}
	unless (defined($str)) {
		$str		= $r->get( $valkey );
if ($CACHING) {
		$self->cache->set( $valkey, $str );
}
	}
	return unless ($str);
	my $node	= $p->parse_node( $str );
	return $node;
}

sub _node_id {
	my $self	= shift;
	my $node	= shift;
	my $r		= $self->conn;
	my $s		= RDF::Trine::Serializer::NTriples->new();
	my $str		= $s->serialize_node( $node );
	my $idkey	= "RT:node.id.$str";
	my $id;
if ($CACHING) {
	$id			= $self->cache->get($idkey);
}
	unless (defined($id)) {
		$id		= $r->get( $idkey );
if ($CACHING) {
		$self->cache->set( $idkey, $id );
}
	}
	return $id if (defined($id));
	
	$id			= $r->incr( 'node.next' );
	my $valkey	= "RT:node.value.$id";
	$r->set( $idkey, $id );
	$r->set( $valkey, $str );
	return $id;
}

=item C<< add_statement ( $statement [, $context] ) >>

Adds the specified C<$statement> to the underlying model.

=cut

sub add_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to add_statement";
	}
	
	if ($st->isa('RDF::Trine::Statement::Quad') and blessed($context)) {
		throw RDF::Trine::Error::MethodInvocationError -text => "add_statement cannot be called with both a quad and a context";
	}
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_add_statements', $st, $context]);
	} else {
		my $r		= $self->conn;
		my @nodes	= $st->nodes;
		$nodes[3]	= $context if ($context);
		@nodes		= map { defined($_) ? $_ : RDF::Trine::Node::Nil->new } @nodes[0..3];
		my @ids		= map { $self->_node_id($_) } @nodes;
		my $key		= join(':', @ids);
		$r->set( "RT:spog:$key", 1 );
		$r->sadd( "RT:sset:$ids[0]", $key );
		$r->sadd( "RT:pset:$ids[1]", $key );
		$r->sadd( "RT:oset:$ids[2]", $key );
		$r->sadd( "RT:gset:$ids[3]", $key );
	}
	return;
}

=item C<< remove_statement ( $statement [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statement {
	my $self	= shift;
	my $st		= shift;
	my $context	= shift;
	
	unless (blessed($st) and $st->isa('RDF::Trine::Statement')) {
		throw RDF::Trine::Error::MethodInvocationError -text => "Not a valid statement object passed to remove_statement";
	}
	
	if ($st->isa('RDF::Trine::Statement::Quad') and blessed($context)) {
		throw RDF::Trine::Error::MethodInvocationError -text => "remove_statement cannot be called with both a quad and a context";
	}
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statements', $st, $context]);
	} else {
		my $r		= $self->conn;
		my @nodes	= $st->nodes;
		$nodes[3]	= $context if ($context);
		@nodes		= map { defined($_) ? $_ : RDF::Trine::Node::Nil->new } @nodes[0..3];
		my @ids		= map { $self->_node_id($_) } @nodes;
		my $key		= join(':', @ids);
		$r->del( "RT:spog:$key" );
		$r->srem( "RT:sset:$ids[0]", $key );
		$r->srem( "RT:pset:$ids[1]", $key );
		$r->srem( "RT:oset:$ids[2]", $key );
		$r->srem( "RT:gset:$ids[3]", $key );
	}
	return;
}

=item C<< remove_statements ( $subject, $predicate, $object [, $context]) >>

Removes the specified C<$statement> from the underlying model.

=cut

sub remove_statements {
	my $self	= shift;
	my @nodes	= @_[0..3];
	my $st		= RDF::Trine::Statement->new( @nodes[0..2] );
	my $context	= $nodes[3];
	
	if ($self->_bulk_ops) {
		push(@{ $self->{ ops } }, ['_remove_statement_patterns', $st, $context]);
	} else {
		$nodes[3]	= 
		my @strs	= map { (not(blessed($_)) or $_->is_variable) ? '*' : $self->_node_id($_) } @nodes;
		my $key		= 'RT:spog:' . join(':', @strs);
		my $r		= $self->conn;
		foreach my $k ($r->keys($key)) {
			my ($sid, $pid, $oid, $gid)	= $k =~ m/RT:spog:(\d+):(\d+):(\d+):(\d+)/;
			$r->srem( "RT:sset:$sid", $_ ) for ($r->smembers("RT:sset:$sid"));
			$r->srem( "RT:pset:$pid", $_ ) for ($r->smembers("RT:pset:$pid"));
			$r->srem( "RT:oset:$oid", $_ ) for ($r->smembers("RT:oset:$oid"));
			$r->srem( "RT:gset:$gid", $_ ) for ($r->smembers("RT:gset:$gid"));
			$r->del( $k );
		}
	}
	return;
}

=item C<< get_statements ($subject, $predicate, $object [, $context] ) >>

Returns a stream object of all statements matching the specified subject,
predicate and objects. Any of the arguments may be undef to match any value.

=cut

sub get_statements {
	my $self	= shift;
	my @nodes	= @_;
	
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		$use_quad	= 1;
	}
	
	my @var_map	= qw(s p o g);
	my %var_map	= map { $var_map[$_] => $_ } (0 .. $#var_map);
	my @node_map;
	foreach my $i (0 .. $#nodes) {
		if (not(blessed($nodes[$i])) or $nodes[$i]->is_variable) {
			$nodes[$i]	= RDF::Trine::Node::Variable->new( $var_map[ $i ] );
		}
	}
	
	my $sub;
	if ($use_quad) {
		my $r	= $self->conn;
		my @skeys;
		my @indexes	= qw(s p o g);
		foreach my $i (0 .. $#indexes) {
			my $index	= $indexes[$i];
			my $n		= $nodes[$i];
			unless ($n->is_variable) {
				my $id	= $self->_node_id($n);
				my $key	= "RT:${index}set:$id";
				push(@skeys, $key);
			}
		}
		if (@skeys) {
			my @keys	= $r->sinter(@skeys);
			$sub		= sub {
				return unless (scalar(@keys));
				my $key		= shift(@keys);
				my @data	= split(':', $key);
				my @nodes	= map { $self->_id_node( $_ ) } @data[0..3];
				my $st		= RDF::Trine::Statement::Quad->new( @nodes );
				return $st;
			};
		} else {
			my @strs	= map { ($_->is_variable) ? '*' : $self->_node_id($_) } @nodes;
			my $key		= 'RT:spog:' . join(':', @strs);
			my @keys	= $r->keys($key);
			$sub		= sub {
				return unless (scalar(@keys));
				my $key		= shift(@keys);
				my @data	= split(':', $key);
				shift(@data);
				my @nodes	= map { $self->_id_node( $_ ) } @data;
				my $st		= RDF::Trine::Statement::Quad->new( @nodes );
				return $st;
			};
		}
	} else {
		my $r	= $self->conn;
		my @skeys;
		my @indexes	= qw(s p o);
		foreach my $i (0 .. $#indexes) {
			my $index	= $indexes[$i];
			my $n		= $nodes[$i];
			unless ($n->is_variable) {
				my $id	= $self->_node_id($n);
				my $key	= "RT:${index}set:$id";
				push(@skeys, $key);
			}
		}
		if (@skeys) {
			my @keys	= $r->sinter(@skeys);
			my %keys;
			foreach (@keys) {
				s/:[^:]+$//;
				$keys{ $_ }++;
			}
			@keys	= keys %keys;
			$sub		= sub {
				return unless (scalar(@keys));
				my $key		= shift(@keys);
				my @data	= split(':', $key);
				my @nodes	= map { $self->_id_node( $_ ) } @data[0..2];
				my $st		= RDF::Trine::Statement->new( @nodes );
				return $st;
			};
		} else {
			my @strs	= map { ($_->is_variable) ? '*' : $self->_node_id($_) } @nodes[0..2];
			my $key		= 'RT:spog:' . join(':', @strs, '*');
			my %triples;
			foreach ($r->keys($key)) {
				s/:[^:]+$//;
				$triples{ $_ }++;
			}
			my @keys	= keys %triples;
			$sub		= sub {
				return unless (scalar(@keys));
				my $key		= shift(@keys);
				my @data	= split(':', $key);
				shift(@data);
				my @nodes	= map { $self->_id_node( $_ ) } @data;
				my $st		= RDF::Trine::Statement->new( @nodes );
				return $st;
			};
		}
	}
	return RDF::Trine::Iterator::Graph->new( $sub );
}

=item C<< count_statements ( $subject, $predicate, $object, $context ) >>

Returns a count of all the statements matching the specified subject,
predicate, object, and context. Any of the arguments may be undef to match any
value.

=cut

sub count_statements {
	my $self	= shift;
	my $use_quad	= 0;
	if (scalar(@_) >= 4) {
		$use_quad	= 1;
# 		warn "count statements with quad" if ($::debug);
	}
	my @nodes	= @_;
	if ($use_quad) {
		my @strs	= map { (not(blessed($_)) or $_->is_variable) ? '*' : $self->_node_id($_) } @nodes[0..3];
		my $key		= 'RT:spog:' . join(':', @strs);
		my $r		= $self->conn;
		my @keys	= $r->keys($key);
		return scalar(@keys);
	} else {
		my @strs	= map { (not(blessed($_)) or $_->is_variable) ? '*' : $self->_node_id($_) } @nodes[0..3];
		my $key		= 'RT:spog:' . join(':', @strs);
		my $r		= $self->conn;
		my @keys	= $r->keys($key);
		my %keys;
		foreach (@keys) {
			s/:[^:]+$//;
			$keys{ $_ }++;
		}
		@keys	= keys %keys;
		return scalar(@keys);
	}
}

=item C<< get_contexts >>

Returns an RDF::Trine::Iterator over the RDF::Trine::Node objects comprising
the set of contexts of the stored quads.

=cut

sub get_contexts {
	my $self	= shift;
	my $r		= $self->conn;
	my @keys	= $r->keys('RT:spog:*');
	my %graphs;
	foreach (@keys) {
		s/^.*://;
		$graphs{ $_ }++;
	}
	my @nodes;
	foreach my $id (keys %graphs) {
		my $node	= $self->_id_node($id);
		next if ($node->isa('RDF::Trine::Node::Nil'));
		push(@nodes, $node);
	}
	return RDF::Trine::Iterator->new( \@nodes );
}


=item C<< supports ( [ $feature ] ) >>

If C<< $feature >> is specified, returns true if the feature is supported by the
store, false otherwise. If C<< $feature >> is not specified, returns a list of
supported features.

=cut

sub supports {
	my $self	= shift;
	my %features	= map { $_ => 1 } (
# 		'http://www.w3.org/ns/sparql-service-description#SPARQL10Query',
# 		'http://www.w3.org/ns/sparql-service-description#SPARQL11Query',
	);
	if (@_) {
		my $f	= shift;
		return $features{ $f };
	} else {
		return keys %features;
	}
}

# =item C<< get_sparql ( $sparql ) >>
# 
# Returns an iterator object of all bindings matching the specified SPARQL query.
# 
# =cut
# 
# sub get_sparql {
# 	my $self	= shift;
# 	my $sparql	= shift;
# 	throw RDF::Trine::Error::UnimplementedError -text => "get_sparql not implemented for Redis stores yet";
# }

sub _bulk_ops {
	return 0;
}

sub _begin_bulk_ops {
	return 0;
}

sub _end_bulk_ops {
	my $self			= shift;
	if (scalar(@{ $self->{ ops } || []})) {
		my @ops	= splice(@{ $self->{ ops } });
		my @aggops	= $self->_group_bulk_ops( @ops );
		my @sparql;
		warn '_end_bulk_ops: ' . Dumper(\@aggops);
		throw RDF::Trine::Error::UnimplementedError -text => "bulk operations not implemented for Redis stores yet";
	}
	$self->{BulkOps}	= 0;
}

=item C<< nuke >>

Permanently removes the store and its data.

=cut

sub nuke {
	my $self	= shift;
	my $r		= $self->conn;
	$r->del('node.next');
	foreach my $k ($r->keys('RT:node.id.*')) {
		$r->del($k);
	}
	foreach my $k ($r->keys('RT:node.value.*')) {
		$r->del($k);
	}
	foreach my $k ($r->keys('RT:spog:*')) {
		$r->del($k);
	}
	$r->del($_) foreach ($r->keys('RT:sset:*'));
	$r->del($_) foreach ($r->keys('RT:pset:*'));
	$r->del($_) foreach ($r->keys('RT:oset:*'));
	$r->del($_) foreach ($r->keys('RT:gset:*'));
	
	$self->{cache}	= Cache::LRU->new( size => $self->{cache_size} );
}


sub _dump {
	my $self	= shift;
	my $r		= $self->conn;
	my @keys	= $r->keys('RT:spog:*');
	warn "--------------------------------------\n";
	warn '*** DUMP Redis statements:';
	warn "$_\n" foreach (@keys);
}

1;

__END__

=back

=head1 BUGS

Please report any bugs or feature requests to C<< <gwilliams@cpan.org> >>.

=head1 AUTHOR

Gregory Todd Williams  C<< <gwilliams@cpan.org> >>

=head1 COPYRIGHT

Copyright (c) 2006-2010 Gregory Todd Williams. This
program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=cut

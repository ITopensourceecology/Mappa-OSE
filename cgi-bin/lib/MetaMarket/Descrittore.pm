package MetaMarket::Descrittore;

use strict;
use warnings;

use Try::Tiny;
use HTTP::Tiny;
use File::Slurp;
use Class::Load::Tiny ':all';

sub descrivi {
	my ($accept, $descr_id, $aggrs, $params) = @_;

	my $descr_class	= "MetaMarket::Descrittore::$descr_id";

	try_load_class($descr_class) or
		die "Descrittore '$descr_id' non trovato\n";

	return $descr_class -> descrivi($accept, @$params, $aggrs);
}

sub filtra {
	my ($self, $data, $func, $value) = @_;

	while (my ($key, $info) = each %$data) {
		delete $data -> {$key}
			unless $func -> ($info, $value);
	}
}

sub trova_data {
	my ($self, $aggrs) = @_;

	my %all_data;
	my $http = HTTP::Tiny -> new;
	my $urls = $self -> trova_url($aggrs);

	foreach my $url (@$urls) {
		my $resp = $http -> get($url);
		next unless $resp -> {'success'};

		my $raw  = $resp -> {'content'};
		my $mime = $resp -> {'headers'} -> {'content-type'};

		my $data = MetaMarket::Data -> converti_da($mime, $raw);

		%all_data = (%all_data, %{$data -> {'locations'}});
	}

	return \%all_data;
}

sub trova_url {
	require XML::Simple;

	my ($self, $aggrs) = @_;

	my @output;

	my $http     = HTTP::Tiny -> new;
	my $base_url = 'http://vitali.web.cs.unibo.it/twiki/pub/TechWeb12';
	my $url      = "$base_url/MetaCatalogo1112/metaCatalogo.xml";
	my $request  = $http -> get($url);

	my $metacatalogo = XML::Simple::XMLin($request -> {'content'});

	while (my ($id, $info) = each %{ $metacatalogo -> {'catalogo'} }) {
		my $request = $http -> get($info -> {'url'});

		my $catalogo = try {
			XML::Simple::XMLin($request -> {'content'})
		};
		next if !$catalogo;

		my $aggregatori = $catalogo -> {'aggregatori'}
			-> {'aggregatore'};

		while (my ($id, $info) = each %$aggregatori) {
			push @output, $info -> {'url'} if $id ~~ @$aggrs;
		}
	}

	return \@output;
}

1;

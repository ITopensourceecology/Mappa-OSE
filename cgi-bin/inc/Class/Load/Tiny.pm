package Class::Load::Tiny;

use strict;
use warnings;

use Carp;
use Try::Tiny;

use base 'Exporter';

our @EXPORT_OK = qw(load_class try_load_class is_class_loaded);
our %EXPORT_TAGS = (all => \@EXPORT_OK);

=head1 NAME

Class::Load::Tiny - a working (require "Class::Name") and (not much) more

=head1 SYNOPSIS

    use Class::Load::Tiny ':all';

    try_load_class('Class::Name')
        or plan skip_all => "Class::Name required to run these tests";

    load_class('Class::Name');

    is_class_loaded('Class::Name');

=head1 DESCRIPTION

B<Class::Load::Tiny> is a minimal implementation of some of the functions of
L<Class::Load>. It is only meant to provide an almost dependency-free version of
the "core" of L<Class::Load>. If you don't need to avoid some more dependencies in
your code, you should probably use L<Class::Load> instead.

=head1 SUBROUTINES

=head2 load_class( $class )

Load C<$class> or throw an error, much like require.

=cut

sub load_class {
	my $class = shift;

	my ($check, $err) = try_load_class($class);

	croak($err) unless $check;

	return 1;
}

=head2 try_load_class( $class )

Load C<$class> and return 1, or 0 if there was an error. In list context, also
return the error string as a second value.

=cut

sub try_load_class {
	my $class = shift;

	my $file = _module_file_from_class($class);

	return try {
		require $file;
		1;
	} catch {
		delete $INC{$file};
		_error($_);
	}
}

=head2 is_class_loaded( $class )

Check if C<$class> is already loaded. Note that, by default, this only checks if
the file named after C<$class> (e.g. C<Module/Name.pm>) is in C<%INC>.

If L<Package::Stash> is installed this function will act just like the more
advanced and reliable one from Class::Load.

=cut

sub is_class_loaded {
	my $class = shift;

	return 0 unless _check_class_name($class);

	if (try_load_class('Package::Stash')) {
		# code copied from Class::Load
		my $stash = Package::Stash -> new($class);

		if ($stash -> has_symbol('$VERSION')) {
			my $version = ${ $stash -> get_symbol('$VERSION') };

			if (defined $version) {
				return 1 if ! ref $version;
				return 1 if ref $version && reftype $version eq 'SCALAR' && defined ${$version};
				return 1 if blessed $version;
			}
		}

		if ($stash -> has_symbol('@ISA')) {
			return 1 if @{ $stash -> get_symbol('@ISA') };
		}

		return 1 if $stash -> list_all_symbols('CODE');
		return 0;
	}

	my $file  = _module_file_from_class($class);

	return (exists $INC{$file}) ? 1 : 0;
}

=head1 INTERNAL METHODS

=head2 _module_file_from_class( $class )

Convert C<$class> from C<Module::Name> to C<Module/Name.pm>.

=cut

sub _module_file_from_class {
	my $class = shift;

	croak "Invalid class name" unless _check_class_name($class);

	$class =~ s/::/\//g;

	return "$class.pm";
}

=head2 _check_class_name( $class )

Che if C<$class> is a proper module name.

=cut

sub _check_class_name {
	my $class = shift;

	# regex copied from Module::Runtime
	my $module_name_rx = qr/[A-Z_a-z][0-9A-Z_a-z]*(?:::[0-9A-Z_a-z]+)*/;

	return $class =~ /\A$module_name_rx\z/o;
}

=head2 _error( $error )

Return 0. 0 and C<$error> in list context.

=cut

sub _error {
	my $err = shift;
	return 0 unless wantarray;
	return 0, $err;
}

=head1 AUTHOR

Alessandro Ghedini <alexbio@cpan.org>

=head1 SEE ALSO

L<Class::Load>

=head1 LICENSE AND COPYRIGHT

Copyright 2011 Alessandro Ghedini.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut

1; # End of Class::Load::Tiny

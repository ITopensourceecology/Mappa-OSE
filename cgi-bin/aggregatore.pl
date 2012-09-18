#!/usr/bin/perl

use v5.10;

use strict;
use warnings;

use lib 'lib';
use lib 'inc';

use CGI;
use Try::Tiny;

use MetaMarket::Aggregatore;

my $q = CGI -> new;

my $aggr_id	= $q -> param('id');
my $key		= lc($q -> param('key'));
my $comp	= lc($q -> param('comp'));
my $value	= lc($q -> param('val'));

my ($mime, $data);

my $status = try {
	my $method = $q -> request_method;

	die "Metodo '$method' non consentito\n"
		unless $method eq 'GET';

	($mime, $data) = MetaMarket::Aggregatore::aggrega(
		$aggr_id, $key, $comp, $value
	);

	return 200;
} catch {
	my $err = $_;

	chomp $err; $data = $err;
	$mime = 'text/plain';

	given ($err) {
		when (/non trovato/)    { return 404 }
		when (/non consentito/) { return 405 }
		when (/non valido/)     { return 406 }
		when (/non supportato/) { return 406 }
		default                 { return 500 }
	}
};

print $q -> header(
	-type => $mime,
	-charset => 'utf-8',
	-status => $status
);

say $data;

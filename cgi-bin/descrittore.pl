#!/usr/bin/perl

use v5.10;

use strict;
use warnings;

use lib 'lib';
use lib 'inc';

use CGI;
use Try::Tiny;

use MetaMarket::Descrittore;

my $q = CGI -> new;

my $descr_id	= $q -> param('id');
my $aggrs_j	= $q -> param('aggrs');
my $params_j	= $q -> param('params');
my @accept	= $q -> Accept();

$accept[0] = 'application/json'
	if $accept[0] eq '*/*';

my @aggrs  = split '\/', $aggrs_j;
my @params = split '\/', $params_j;

my ($mime, $data);

my $status = try {
	my $method = $q -> request_method;

	die "Metodo '$method' non consentito\n"
		unless $method eq 'GET';

	($mime, $data) = MetaMarket::Descrittore::descrivi(
		\@accept, $descr_id, \@aggrs, \@params
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

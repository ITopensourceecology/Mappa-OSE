package MetaMarket::Aggregatore;

use v5.10;

use strict;
use warnings;

use File::Slurp;
use MetaMarket::Data;

use Class::Load::Tiny ':all';

sub aggrega {
	my ($aggr_id, $key, $op, $value) = @_;

	my $aggr_class	= "MetaMarket::Aggregatore::$aggr_id";

	try_load_class($aggr_class) or
		die "Aggregatore '$aggr_id' non trovato\n";

	my $mime = $aggr_class -> mime;
	my $raw  = read_file($aggr_class -> file);

	my $data = MetaMarket::Data -> converti_da($mime, $raw);

	MetaMarket::Aggregatore -> filter($data, $key, $op, $value)
		if $key and $op and $value;

	my $output = MetaMarket::Data -> converti_a($mime, $data);

	return ($mime, $output);
}

sub filter_eq {
	my ($data, $key, $value) = @_;

	while (my ($chi, $info) = each %{$data -> {"locations"}}){
		if (ref $info -> {$key} eq 'ARRAY'){
			my $flag = 1;

			foreach (@{$info -> {$key}}){
				$flag = 0 if $_ =~ /$value/i;
			}

			delete($data -> {"locations"}{$chi}) if $flag;
		} else {
			delete($data -> {"locations"}{$chi})
				unless $info -> {$key} =~ /$value/i;
		}
	}
}

sub filter_eqq {
	my ($data, $key, $value) = @_;

	while (my ($chi, $info) = each %{$data -> {"locations"}}){
		if (ref $info -> {$key} eq 'ARRAY'){
			my $flag = 1;

			foreach (@{$info -> {$key}}){
				$flag = 0 if lc $_ eq lc $value;
			}

			delete($data -> {"locations"}{$chi}) if $flag;
		} else {
			delete($data -> {"locations"}{$chi})
				unless lc $info -> {$key} eq lc $value;
		}
	}
}

sub filter_gt {
	my ($data, $key, $value) = @_;

	while (my ($chi, $info) = each %{$data -> {"locations"}}){
		if (ref $info -> {$key} eq 'ARRAY'){
			my $flag = 1;

			foreach (@{$info -> {$key}}){
				$flag = 0 if lc $_ gt lc $value;
			}

			delete($data -> {"locations"}{$chi}) if $flag;
		} else {
			delete($data -> {"locations"}{$chi})
				unless lc $info -> {$key} gt lc $value;
		}
	}
}

sub filter_lt {
	my ($data, $key, $value) = @_;

	while (my ($chi, $info) = each %{$data -> {"locations"}}){
		if (ref $info -> {$key} eq 'ARRAY'){
			my $flag = 1;

			foreach (@{$info -> {$key}}){
				$flag = 0 if lc $_ lt lc $value
			}

			delete($data -> {"locations"}{$chi}) if $flag;
		} else {
			delete($data -> {"locations"}{$chi})
				unless lc $info -> {$key} lt lc $value;
		}
	}
}

sub filter_ge {
	my ($data, $key, $value) = @_;

	while (my ($chi, $info) = each %{$data -> {"locations"}}){
		if (ref $info -> {$key} eq 'ARRAY'){
			my $flag = 1;

			foreach (@{$info -> {$key}}){
				$flag = 0 if lc $_ ge lc $value;
			}

			delete($data -> {"locations"}{$chi}) if $flag;
		} else {
			delete($data -> {"locations"}{$chi})
				unless lc $info -> {$key} ge lc $value
		}
	}
}

sub filter_le {
	my ($data, $key, $value) = @_;

	while (my ($chi, $info) = each %{$data -> {"locations"}}){
		if (ref $info -> {$key} eq 'ARRAY'){
			my $flag = 1;

			foreach (@{$info -> {$key}}){
				$flag = 0 if lc $_ le lc $value;
			}

			delete($data -> {"locations"}{$chi}) if $flag;
		} else {
			delete($data -> {"locations"}{$chi})
				unless lc $info -> {$key} le lc $value;
		}
	}
}

sub filter {
	my ($self, $data, $key, $op, $value) = @_;

	given ($op){
		when ("contains") {
			filter_eq($data, $key, $value);
		}
		when ("eq") {
			filter_eqq($data, $key, $value);
		}
		when ("gt") {
			filter_gt($data, $key, $value);
		}
		when ("lt") {
			filter_lt($data, $key, $value);
		}
		when ("ge") {
			filter_ge($data, $key, $value);
		}
		when ("le") {
			filter_le($data, $key, $value);
		}
		default {
			die "Operatore '$op' non supportato\n";
		}
	}
}

1;

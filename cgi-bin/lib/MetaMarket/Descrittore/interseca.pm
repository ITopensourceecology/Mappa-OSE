package MetaMarket::Descrittore::interseca;

use base 'MetaMarket::Descrittore';

use threads;
use MetaMarket::Data;

sub descrivi {
	my ($self, $accept, $lat, $long, $raggio, $categs, $nome, $aggrs) = @_;

	my $format = $accept -> [0];

	my $traggio = threads -> create(\&run_raggio, $accept, $lat, $long, $raggio, $aggrs);
	my $tcategs = threads -> create(\&run_categs, $accept, $categs, $aggrs);
	my $tnome   = threads -> create(\&run_nome, $accept, $nome, $aggrs);

	my $draggio = $traggio -> join;
	my $dcategs = $tcategs -> join;
	my $dnome   = $nome eq 'undef' ? undef : $tnome -> join;

	my $data = MetaMarket::Data::interseca($draggio, $dcategs, $dnome);

	my $raw = MetaMarket::Data
		-> converti_a($format, $data);

	return ($format, $raw);
}

sub run_raggio {
	require MetaMarket::Descrittore::raggio;

	my ($accept, $lat, $long, $raggio, $aggrs) = @_;

	my ($mraggio, $rraggio) = MetaMarket::Descrittore::raggio
		-> descrivi($accept, $lat, $long, $raggio, $aggrs);

	return MetaMarket::Data -> converti_da($mraggio, $rraggio);
}

sub run_categs {
	require MetaMarket::Descrittore::tipologiap;

	my ($accept, $categs, $aggrs) = @_;

	my ($mcateg, $rcateg) = MetaMarket::Descrittore::tipologiap
		-> descrivi($accept, 'or', $categs, $aggrs);

	return MetaMarket::Data -> converti_da($mcateg, $rcateg);
}

sub run_nome {
	require MetaMarket::Descrittore::trova;

	my ($accept, $nome, $aggrs) = @_;

	my ($mnome, $rnome) = MetaMarket::Descrittore::trova
		-> descrivi($accept, $nome, $aggrs);

	return MetaMarket::Data -> converti_da($mnome, $rnome);
}

1;

package MetaMarket::Descrittore::tipologiap;

use base 'MetaMarket::Descrittore';

use MetaMarket::Data;

use HTTP::Tiny;
use URI::Escape;

sub descrivi {
	my ($self, $accept, $op, $p) = @_;

	if ($op eq 'list') {
		$accept = 'application/xml';
	} else {
		$accept = 'application/json';
	}

	$p = uri_escape($p);

	my $req_url = "http://ltw1140.web.cs.unibo.it/tipologia/params/$op/$p";

	my $request = HTTP::Tiny -> new -> get($req_url, {
		headers => { 'accept' => $accept }
	});

	die $request -> {'content'}
		unless $request -> {'success'};

	return ($accept, $request -> {'content'});
}

1;

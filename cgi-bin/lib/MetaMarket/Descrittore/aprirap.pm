package MetaMarket::Descrittore::aprirap;

use base 'MetaMarket::Descrittore';

use MetaMarket::Data;

use HTTP::Tiny;
use URI::Escape;

sub descrivi {
	my ($self, $accept, $p1, $p2) = @_;

	$accept = 'text/plain';

	$p1 = uri_escape($p1);
	$p2 = uri_escape($p2);

	my $req_url = "http://ltw1135.web.cs.unibo.it/aprira/params/$p1/$p2";

	my $request = HTTP::Tiny -> new -> get($req_url, {
		headers => { 'accept' => $accept }
	});

	die $request -> {'content'}
		unless $request -> {'success'};

	return ($accept, $request -> {'content'});
}

1;

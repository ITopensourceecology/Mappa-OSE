package MetaMarket::Descrittore::distanza;

use base 'MetaMarket::Descrittore';

use Geo::Distance;

sub  descrivi {
	my ($self, $accept, $lat1, $lon1, $lat2, $lon2) = @_;

	my $geo  = Geo::Distance -> new;
	my $dist = $geo -> distance('meter', $lon1,$lat1 => $lon2,$lat2);

	return ('text/plain', $dist);
}

1;

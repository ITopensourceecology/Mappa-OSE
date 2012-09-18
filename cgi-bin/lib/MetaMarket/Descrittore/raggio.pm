package MetaMarket::Descrittore::raggio;

use base 'MetaMarket::Descrittore';

use POSIX;
use Geo::Distance;

use MetaMarket::Data;

sub descrivi {
	my ($self, $accept, $lat, $long, $raggio, $aggrs) = @_;

	my $data = $self -> trova_data($aggrs);

	my $point = {
		lat    => $lat,
		long   => $long,
		radius => $raggio
	};

	my $filtro = sub {
		my ($location, $value) = @_;

		my $lon1 = $value -> {'long'};
		my $lat1 = $value -> {'lat'};
		my $lon2 = $location -> {'long'};
		my $lat2 = $location -> {'lat'};

		$lon2 = $location -> {'Long'}
			unless $lon2;
		$lat2 = $location -> {'Lat'}
			unless $lat2;

		my $geo  = Geo::Distance -> new;
		my $dist = floor($geo -> distance(
			'meter', $lon1, $lat1 => $lon2, $lat2
		));

		return ($dist < $value -> {'radius'});
	};

	$self -> filtra($data, $filtro, $point);

	my $format = $accept -> [0];

	my $raw = MetaMarket::Data
		-> converti_a($format, { locations => $data });

	return ($format, $raw);
}

1;

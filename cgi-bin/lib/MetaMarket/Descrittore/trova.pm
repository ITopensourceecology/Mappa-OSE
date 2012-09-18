package MetaMarket::Descrittore::trova;

use base 'MetaMarket::Descrittore';

use MetaMarket::Data;

sub descrivi {
	my ($self, $accept, $nome, $aggrs) = @_;

	my $data = $self -> trova_data($aggrs);

	my $filtro = sub {
		my ($location, $nome) = @_;

		my $name = $location -> {'name'};

		$name = $location -> {'Name'}
			unless $name;

		return ($name =~ /$nome/i) ? 1 : 0;
	};

	$self -> filtra($data, $filtro, $nome);

	my $format = $accept -> [0];

	my $raw = MetaMarket::Data
		-> converti_a($format, { locations => $data });

	return ($format, $raw);
}

1;

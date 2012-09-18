sub csvizza{
	require Set::Scalar;

	my ($ref, $metadata, $name) = @_;
	my ($data, $fields);

	my $metadatafields = Set::Scalar -> new;
	my ($keyy, $infoo) = each %{$ref -> {$name}};

	while (my ($key, $info) = each %$infoo) {
		push @{$fields}, $key;
	}

	while (my ($key, $info) = each %{$ref -> {$metadata}}) {
		push @{$fields}, $key;
		$metadatafields -> insert($key);
        }

	push @{$data}, $fields;

	while (my ($keyy, $infoo) = each %{$ref -> {$name}}) {
		my $temp;

		foreach (@{$fields}){
			if ($metadatafields -> has($_)){
				push @{$temp}, $ref -> {$metadata}{$_};
			} else {
				if (lc $_ eq "category"){
					my $tostring="";
					foreach (my $element=@{$infoo->{$_}}){
						$tostring = $tostring.$element;
					}
					push @{$temp}, $tostring;
				} else {
					push @{$temp}, $infoo -> {$_};
				}
			}
		}

		push @{$data}, $temp;
	}

	return $data;
}

sub a_csv{
	require Text::CSV;

	my ($self, $data) = @_;

	my $csv = Text::CSV -> new({ binary => 1 });

	my $output = "";
	my $tocsv  = csvizza($data, "metadata", "locations");

	foreach (@{$tocsv}) {
		$output = $output."\n".$csv -> string
			if $csv -> combine(@{$_});
	}

	return  $output;
}

# FIXME doresnt work quite yet...
sub a_turtle {
	my ($self, $data) = @_;
#	$data->{"locations"}{"metadata"}=%{$data->{"metadata"}};
	$data={metadata => $data->{nocasekey($data,"metadata")}, %{$data->{nocasekey($data,"locations")}}};
	my $out="\@prefix : ";
	if (exists $data->{nocasekey ($data,'metadata')}{nocasekey($data->{'metadata'},'source')})
	{
		$out .= "<$data->{'metadata'}{'source'}> .\n";
	} else {
		$out .= "</> .\n";
	}
my $count =0;
	while (my ($chiave, $entry)=each(%{$data})){

		my $id=nocasekey($entry,'id');
		if (lc $chiave ne 'metadata') 
		{
			if ($id eq "UNKNOWN") {$id = "el$count";$count++};
		}
		$out .= "\n:$entry->{$id}\n	";
		while (my ($key,$val) = each %$entry) {
			if (lc $key eq "category") {
				$val = join (",",@{$val});
			}
			$out .= " :$key \"$val\" \n	;";	
		}
		$out=~s/\n	;$/.\n/
	}
	
	return $out;	
}

sub trim_categs{
	my $data=shift;
	my @categs=split(/,/,shift);
	my %categs=map{$_ =>1} @categs;
	while (my(undef,$element) = each %{$data-> {'locations'}}){
		my @elcategs = @{$element->{nocasekey($element,'category')}};
		my %elcategs=map{$_ =>1}@elcategs;
		my $key = nocasekey($element,'category');
		my @cc = grep($elcategs{$_},@categs);
		@{$element->{$key}} = @cc;
	}
}

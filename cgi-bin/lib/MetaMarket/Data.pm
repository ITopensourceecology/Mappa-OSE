package MetaMarket::Data;

use v5.10;

use strict;
use warnings;

# --- turn one scalar element into array of one
sub arrayfica {
	my ($target) = shift;
	$$target = [$$target];
}

# --- turn the data in xml format to standard format this is due to
#	inconsistences of the protocol
sub dexmlizza {
	my ($ref, $name)= @_;

	while (my ($key, $info) = each %{$ref -> {$name}}) {
		my $opening = '';
		my $openingk = nocasekey ($info,"opening");
		my $closingk = nocasekey($info,"closing");
		given (ref $info -> {$openingk}){
			when('HASH') {
				$opening .= $info -> {$openingk} -> {"content"};
			};
			when ('ARRAY'){
				$opening .= $_ -> {"content"} foreach (@{$info -> {"opening"}});
			};
			when ("UNKNOWN"){};
			default {
				$opening = $info -> {$openingk} 
			};
			
		}

		# turn opening and closing into the proper format (string and
		# array of strings respectively)
		$info -> {"opening"} = $opening;
		$info -> {"closing"} = $info -> {"closing"} -> {"content"} if (ref $info -> {"closing"} eq 'HASH');
		arrayfica(\$info -> {"category"}) unless (ref $info -> {"category"} eq 'ARRAY');
		if ($openingk ne "opening") {delete $info -> {$openingk};};
		if ($closingk ne "closing") {delete $info -> {$closingk};};
		# name is put in the new field "name", this to prevent
		# discrepancy with json format which uses the id as name of the
		# location, also all fields are supposed to be searched inside
		# each location"s hash, therefore the key field should not be
		# used outside formatting functions (such as this)
		$info -> {"name"} = $key;

	};
}

# --- turn json to standard (that is, put the name of the json location in the
#	field "id", for a tidier handling, the key field sould not be used
#	outside formatting functions
sub dejsonizza {
	my ($ref, $name) = @_;

	while (my ($key, $info) = each %{$ref -> {$name}}) {
		$info -> {"id"} = $key;
	}
}

# --- exchanges $field field of the hash with the the name of the entry, and
#	deletes the $field
sub formatta {
	my ($ref, $field, $key, $info) = @_;

	if ((exists $info ->{$field})and($key ne $info -> {$field})) {
		$$ref -> {$info -> {$field}} = $info;
		delete $$ref -> {$key} if (exists $info -> {$field});
	} 
	

	delete $info -> {$field} if (exists $info -> {$field});
}

# --- turn standard into protocol XML for conversion

sub xmlizza{
	my ($ref, $data) = @_;
	my $count=0;
	while (my ($key, $info) = each %{$ref -> {$data}}) {
		my $name = nocasekey($info, "name");
		if (($name eq "UNKNOWN")or($info -> {$name} ne "*")){$name = "$count";$count++;};
		formatta(\$ref -> {$data}, $name, $key, $info);

		# turn opening and closing into the proper format (string and
		# array of strings respectively)
		#$info -> {"opening"} = $opening;
		foreach (keys %{$info}){
			given (lc $_){
				when ("closing"){
					my  $tmp = $info -> {lc $_};
					if (exists $info -> {"closing"}) {
						undef $info -> {"closing"};
					} else	{
						delete $info -> {$_};
					}

					$info -> {"closing"}{"showAs"}  = "festivi";
					$info -> {"closing"}{"content"} = $tmp;
				};
				when ("opening"){
					my @opening = split (/[.]/,$info -> {$_});
					if (exists $info -> {"opening"}) {
						$info -> {"opening"}=[];
					} else	{
						delete $info -> {$_};
					}
					foreach my $op (@opening){
						my $tipo ="";
						if ($op=~m/^(20| 20)/) {$tipo = "Di turno"};
						if ($op=~m/Sun/) {$tipo .= "Domenica "};
						if ($op=~m/Mon/) {$tipo .= "Lunedi "};
						if ($op=~m/Tue/) {$tipo .= "Martedi "};
						if ($op=~m/Thu/) {$tipo .= "Mercoledi "};
						if ($op=~m/Fry/) {$tipo .= "Giovedi "};
						if ($op=~m/Wed/) {$tipo .= "Venerdi "};
						if ($op=~m/Sat/) {$tipo .= "Sabato "};
						if ($tipo eq "") {$tipo = "sconosciuto"};
						$info -> {"opening"}=[
							@{$info->{"opening"}},
							{
								showAs=>$tipo,
								content =>"$op."
							}
						];
					}
				};
				when ("category"){};
 				when("id") {};
 				when("lat"){};
 				when("long") {};
				default {
					my $tmp = $info -> {$_};
					undef $info -> {$_};
					$info -> {$_} =[$tmp];
				};
			}
		}
		# name is put in the new field "name", this to prevent
		# discrepancy with json format which uses the id as name of the
		# location, also all fields are supposed to be searched inside
		# each location"s hash, therefore the key field should not be
		# used outside formatting functions (such as this)
		#$info -> {"name"} = $key;
	}
}

# --- finds the given key in a non case sensitive way, and returns the exact key
sub nocasekey{
	my ($hash, $field) = @_;

	foreach (keys %{$hash}) {
		return $_ if (lc $_ eq lc $field);
	}
	return "UNKNOWN";
}

# --- turn standard into JSON. this mainly means putting the id field as name
#	of each entry and deleting the id field (
sub jsonizza{
	my ($ref, $data) = @_;

	while (my ($key, $info) = each %{$ref -> {$data}}) {
		my $count =0;
		my $id = nocasekey($info, "id");
		if ($id eq "UNKNOWN") {$id = "$count";$count++};
		formatta(\$ref -> {$data}, $id, $key, $info);
		delete $info -> {$id};
	}
}
sub deturtleizza{
	my $data = shift;
		while (my ($key, $info) = each %$data)  {
			delete $data -> {$key};
			$key =~ s/^\///;
			while (my ($key1, $info1) = each %$info){
					delete $info->{$key1};
					$key1 =~ s/^\///;
					$info->{$key1}=$info1;
					if (ref $info1 eq 'ARRAY'){
						foreach(@$info1){
							$info->{$key1}=$_->{"value"};
						}
						
					}
			}
			if ((lc $key eq "metadata") or(lc $key eq "locations")){
				$data -> {$key} = $info;
			}
			else {
				$data -> {"locations"}{$key} = $info; if (lc $info -> {"category"} =~ /,/){
					$info -> {"category"} = [split (/,/,$info -> {"category"})];
				}
				else {
					arrayfica(\$info -> {"category"});
				}
			}
		}
	return $data;
}

# --- generic parsing
sub converti_da {
	my ($self, $mime, $file) = @_;

	given ($mime) {
		when (/application\/xml/)  { return da_xml($self, $file)    }
		when (/application\/json/) { return da_json($self, $file)   }
		when (/text\/turtle/)      { return da_turtle($self, $file) }
		when (/text\/csv/)         { return da_csv($self, $file)    }
		default                    { die "Tipo MIME '$mime' non supportato\n" }
	}
}

# --- generic parsing
sub converti_a {
	my ($self, $mime, $data) = @_;

	given ($mime) {
		when (/application\/json/) { return a_json($self, $data)   }
		when (/application\/xml/)  { return a_xml($self, $data)   }
		default                    { die "Tipo MIME '$mime' non supportato\n" }
	}
}

# --- xml parsing
sub da_xml {
	require XML::Simple;

	my ($self, $file) = @_;

	# read XML file
	my $data = XML::Simple::XMLin($file);
	my $location=nocasekey($data,"location");
	if ($location ne "UNKNOWN"){
		$data -> {"locations"} = $data -> {$location};
		delete($data -> {$location});
	}
	dexmlizza($data,"locations");

	#  output
	return $data;
}

sub a_xml {
	require XML::Simple;

	my ($self, $data) = @_;

	$data -> {"location"} = $data -> {"locations"};
	delete($data -> {"locations"});
	xmlizza($data, "location");

	# finally turn into XML
	my $output = XML::Simple::XMLout($data);

	#  output
	$output=~s/^\<opt/\<?xml version=\'1.0\' encoding=\"UTF-8\"\?\>\<!DOCTYPE locations SYSTEM \"http:\/\/vitali.web.cs.unibo.it\/twiki\/pub\/TechWeb12\/DTDs\/locations.dtdi\"\>\<locations/;
	$output =~ s/opt\>$/locations\>/;
return $output;
}

# --- turtle parsing NOTE: "category" may have morethan ne entry (thus it"san array)
#     but there"s no protocol specification for that, using "," to encode it
sub da_turtle {
	require RDF::Trine::Parser::Turtle;
	require RDF::Trine::Model;
	my ($self, $in) = @_;
	my $parser	= RDF::Trine::Parser->new("turtle");
	my $model	= RDF::Trine::Model->new();
	$in =~ s/<.*>/<>/g; 
	$parser->parse_into_model (".",$in,$model);
	my $data=deturtleizza($model->as_hashref);
	return $data;
}

# --- CSV parsing
sub da_csv {
	require Text::CSV;
	require Set::Scalar;

	my ($self, $file) = @_;

	my $first = 1;

	# array containing the various keys of the fields (read from the first
	# row)
	my @keys;

	# array containing the position of the metadata fields
	my $metadata = Set::Scalar -> new;
	my $data;

	# variable containing the id, which is going to become the name of the
	# locations entry

	my $csv = Text::CSV -> new({ binary => 1 });
	my @rows= (split(/\n/,$file));
	my $count=0;
	foreach (@rows){
		$csv -> parse ($_);
		my $row= [$csv -> fields()];
		if (!($count)) {
			foreach (@{$row}){
				push @keys, lc $_;

				$metadata -> insert($#keys)
					if (
						(lc $_ eq "created") ||
						(lc $_ eq "creator") ||
						(lc $_ eq "version") ||
						(lc $_ eq "source")  ||
						(lc $_ eq "valid")
					)
			}

		} else {
			my $counter=0;

			foreach (@{$row}){
				if ($metadata -> has($counter)){
					$data -> {"metadata"}{$keys[$counter]} = $_;
				} else {
					$data -> {"locations"}{$count}{$keys[$counter]} = $_;
					if (lc $keys[$counter] eq "category"){
                                                arrayfica(\$data -> {"locations"}{$count}{$keys[$counter]});
                                        }
				}

				$counter++;
			}
		}
		$count++;
	}

	$csv -> eof or $csv -> error_diag;

	return $data;
}

# --- JSON parsing
sub a_json {
	require JSON;

	my ($self, $data) = @_;

	jsonizza($data,"locations");

	return JSON::encode_json($data);
};

sub da_json {
	require JSON;

	my ($self, $data) = @_;
	# convert the data
	$data = JSON::decode_json($data);
	dejsonizza($data,"locations");

	return $data;
}
# write all elements with unique id (idname as 
# some ids are nonexstent and some names are 
# duplicated- but they HAVE id)) on $out this
# way doubles will be overwritten. 
sub unID {
	my $a=shift;
	my $out;
	if ($a) {$out->{'defined'}='exists'} else {return $a}
	while (my($key,$element) = each %{$a-> {'locations'}}){
		$out->{'locations'}->{$element->{nocasekey($element,'id')}.$element->{nocasekey($element,'name')}} =$element;
	}

	return $out;
}

sub interseca {
	my ($a,$b,$c) = @_;
	$a=unID($a);
	$b=unID($b);
	$c=unID($c);
	my @keys = keys %{$a->{'locations'}};
	foreach my $key (@keys) {
		if (!((defined $b->{'locations'}{$key}) and
			((!defined $c) or (defined $c->{'locations'}{$key}))))
		{
			delete $a->{'locations'}{$key};
		}
	}

	return $a;
}

1;

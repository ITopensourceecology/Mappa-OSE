package JSON::Parse;
require Exporter;
@ISA = qw(Exporter);
@EXPORT_OK = qw/json_to_perl valid_json/;
use warnings;
use strict;
our $VERSION = '0.11';
use XSLoader;
XSLoader::load 'JSON::Parse', $VERSION;

1;

__END__

=pod

=encoding utf-8

=head1 NAME

JSON::Parse - Convert JSON into a Perl variable

=head1 SYNOPSIS

    use JSON::Parse 'json_to_perl';
    my $json = '["golden", "fleece"]';
    my $perl = json_to_perl ($json);
    # Same effect as $perl = ['golden', 'fleece'];

Convert JSON into Perl.

=head1 DESCRIPTION

JSON::Parse converts JSON into equivalent Perl. The function
L</json_to_perl> takes one argument, a string containing JSON, and
returns a Perl reference. The input to C<json_to_perl> must be a
complete JSON structure.

The module differs from the standard L<JSON> module by simplifying the
handling of Unicode. If its input is marked as Unicode characters, the
strings in its output are also marked as Unicode characters.

JSON::Parse also provides a high speed validation function,
L</valid_json>.

JSON::Parse is based on C and users require a C compiler to install it.

JSON means "JavaScript Object Notation" and it is specified in L</RFC
4627>.

=head1 FUNCTIONS

=head2 json_to_perl

    use JSON::Parse 'json_to_perl';
    my $perl = json_to_perl ('{"x":1, "y":2}');

This function converts JSON into a Perl structure, either an array
reference or a hash reference.

If the first argument does not contain a valid JSON text,
C<json_to_perl> throws a fatal error. See L</DIAGNOSTICS> for the
possible error messages.

If the argument contains valid JSON, the return value is either a hash
or an array reference. If the input JSON text is a serialized object,
a hash reference is returned:

    my $perl = json_to_perl ('{"a":1, "b":2}');
    print ref $perl, "\n";
    # Prints "HASH".

If the input JSON text is a serialized array, an array reference is
returned:

    my $perl = json_to_perl ('["a", "b", "c"]');
    print ref $perl, "\n";
    # Prints "ARRAY".

=head2 valid_json

    use JSON::Parse 'valid_json';
    if (valid_json ($json)) {
        # do something
    }

C<Valid_json> returns I<1> if its argument is valid JSON and I<0> if not.

Because C<valid_json> does not create any Perl data structures, it
runs about two or three times faster than L</json_to_perl>.

=head1 Mapping from JSON to Perl

JSON elements are mapped to Perl as follows:

=head2 JSON numbers

JSON numbers become Perl strings, rather than numbers. No conversion
from the character string to a numerical value is done. For example

    my $q = @{json_to_perl ('[0.12345]')}[0];

has the same result as a Perl declaration of the form

    my $q = '0.12345';

The conversion is not done because Perl will do the conversion into a
numerical value automatically when the scalar is used in a numerical
context:

    print '0.12345' * 5;
    # prints 0.61725

See also L</Numbers not checked>.

=head2 JSON strings

JSON strings become Perl strings. The JSON escape characters such as
\t for the tab character (see section 2.5 of L</RFC 4627>) are mapped
to the equivalent ASCII character. Unicode escape characters of the
form \uXXXX (see page three of L</RFC 4627>) are mapped to UTF-8
octets. This is done regardless of what input encoding might be used
in the JSON text.

=head3 Handling of Unicode

If the input to L</json_to_perl> is marked as Unicode characters, the
output strings will be marked as Unicode characters. If the input is
not marked as Unicode characters, the output strings will not be
marked as Unicode characters. Thus, 

    # The scalar $sasori looks like Unicode to Perl
    use utf8;
    my $sasori = '["蠍"]';
    my $p = json_to_perl ($sasori);
    print utf8::is_utf8 ($p->[0]);
    # Prints 1.

but

    # The scalar $ebi does not look like Unicode to Perl
    no utf8;
    my $ebi = '["海老"]';
    my $p = json_to_perl ($ebi);
    print utf8::is_utf8 ($p->[0]);
    # Prints nothing.

=head2 JSON arrays

JSON arrays become Perl array references. The elements of the Perl
array are in the same order as they appear in the JSON.

Thus

    my $p = json_to_perl ('["monday", "tuesday", "wednesday"]');

has the same result as a Perl declaration of the form

    my $p = [ 'monday', 'tuesday', 'wednesday' ];

=head2 JSON objects

JSON objects become Perl hashes. The members of the object are mapped
to pairs of key and value in the Perl hash. The string part of each
object member becomes the key of the Perl hash. The value part of each
member is mapped to the value of the Perl hash.

Thus

    my $j = <<EOF;
    {"monday":["blue", "black"],
     "tuesday":["grey", "heart attack"],
     "friday":"Gotta get down on Friday"}
    EOF

    my $p = json_to_perl ($j);

has the same result as a Perl declaration of the form

    my $p = {
        monday => ['blue', 'black'],
        tuesday => ['grey', 'heart attack'],
        friday => 'Gotta get down on Friday',
    };

=head2 null

The JSON null literal is mapped to the undefined value.
See L</False = null = undefined value>.

=head2 true

The JSON true literal is mapped to a Perl string with the value 'true'.

=head2 false

The JSON false literal is mapped to the undefined value.
See L</False = null = undefined value>.

=head1 RESTRICTIONS

This module imposes the following restrictions on its input.

=over

=item JSON only

JSON::Parse is a strict parser. It only parses JSON which exactly
meets the criteria of L</RFC 4627>. That means, for example, unlike
the standard L<JSON> module, JSON::Parse does not accept single quotes
(') instead of double quotes ("), or numbers with leading zeros, like
0123.

=item No incremental parsing

JSON::Parse does not do incremental parsing. JSON::Parse only parses
fully-formed JSON strings which include opening and closing brackets.

=item UTF-8 only

Although JSON may come in various encodings of Unicode, JSON::Parse
only parses the UTF-8 format. If input is in a different Unicode
encoding than UTF-8, convert the input before handing it to this
module. For example, for the UTF-16 format,

    use Encode 'decode';
    my $input_utf8 = decode ('UTF-16', $input);
    my $perl = json_to_perl ($input_utf8);

or, for a file,

    open my $input, "<:encoding(UTF-16)", 'some-json-file'; 

This module does not attempt to do the determination of the nature of
the octet stream, as described in part 3 of L</RFC 4627>.

=back

=head1 BUGS

This is a preliminary version. The following deficiencies are
known. These may be resolved in a later version.

=over

=item False = null = undefined value

At the moment, both of "false" and "null" in JSON are mapped to the
undefined value. "true" is mapped to the string "true".

=item Numbers not checked

The author of this module does not know whether all possible JSON
floating point numbers are understood by Perl (see L</JSON numbers>
above). Most integer and floating point numbers encountered should be
OK, but there is a chance that there are some numbers allowed in the
JSON format which Perl cannot understand.

=item Line numbers are off by one

The line numbers in the error messages are off by one (line 1 is line
0).

=item Compilation failure on Windows compilers

The C code which JSON::Parse is based on uses some dialect features of
the GNU version of C, and it will not compile on some Microsoft
Windows compilers.

=item C compiler required

At the moment there is no "pure Perl" version of the module, so use of
the module requires a C compiler.

=back

=head1 DIAGNOSTICS

L</Valid_json> does not produce error messages. L</Json_to_perl> may
produce the following:

=over

=item * unknown failure

=item * a callback routine failed

=item * out of memory

=item * parser failed (this JSON is not grammatically correct)

=item * lexer failed (there are stray characters in the input)

=item * unimplemented feature of JSON encountered in input

=item * Unicode \uXXXX decoding failed

=item * input was empty

=item * the text did not start with { or [ as it should have

=item * met an unknown escape sequence (backslash \ + character)

=back

Error messages have the line number and the byte number of the input
which caused the problem.

(The above error messages are in the file F<json_parse.c> in the top
level of the distribution. The "callback routine failed" and "out of
memory" errors are unlikely to occur in normal usage.)

Parsing errors are fatal, so to continue after an error occurs, put
the parsing into an C<eval> block:

    my $p;                       
    eval {                       
        $p = json_to_perl ($j);  
    };                           
    if ($@) {                    
        # handle error           
    }

=head1 SEE ALSO

=over

=item RFC 4627

JSON is specified in RFC (Request For Comments, a kind of internet
standards document) 4627. See, for example,
L<http://www.ietf.org/rfc/rfc4627.txt>.

=back

=head1 EXPORTS

The module exports nothing by default. Functions L</json_to_perl> and
L</valid_json> can be exported on request.

=head1 AUTHOR

Ben Bullock, <bkb@cpan.org>

=head1 LICENSE

JSON::Parse can be used, copied, modified and redistributed under the
same terms as Perl itself.

=cut


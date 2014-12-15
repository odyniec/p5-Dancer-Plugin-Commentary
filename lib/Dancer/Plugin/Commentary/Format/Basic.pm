package Dancer::Plugin::Commentary::Format::Basic;

use strict;
use warnings;

use parent 'Dancer::Plugin::Commentary::Format';

sub to_html {
    my ($text) = @_;

    # Strip leading and trailing whitespace
    $text =~ s{^\s+|\s+$}{}gs;

    # Replace text URLs with anchors (monstrous regexp borrowed from URI::Find)
    $text =~ s{
        (?^:[a-zA-Z][a-zA-Z0-9\+]*):
        [\;\/\?\\@\&\=\+\$\,\[\]\p{isAlpha}A-Za-z0-9\-_\.\!\~\*\'\(\)%]
        [\;\/\?\:\@\&\=\+\$\,\[\]\p{isAlpha}A-Za-z0-9\-_\.\!\~\*\'\(\)%\#]*
    }{<a href="$&">$&</a>}gsx;

    # Make paragraphs
    $text =~ s{\n\n}{</p><p>}gs;
    $text = "<p>$text</p>";

    # Replace single line breaks with <br>s
    $text =~ s{\n}{<br/>}gs;

    return $text;
}

1;

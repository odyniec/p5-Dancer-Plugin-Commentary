package Dancer::Plugin::Commentary::Format::Basic;

use strict;
use warnings;

use parent 'Dancer::Plugin::Commentary::Format';

sub to_html {
    my ($text) = @_;

    # Replace text URLs with anchors (monstrous regexp borrowed from URI::Find)
    $text =~ s{
        (?^:[a-zA-Z][a-zA-Z0-9\+]*):
        [\;\/\?\\@\&\=\+\$\,\[\]\p{isAlpha}A-Za-z0-9\-_\.\!\~\*\'\(\)%]
        [\;\/\?\:\@\&\=\+\$\,\[\]\p{isAlpha}A-Za-z0-9\-_\.\!\~\*\'\(\)%\#]*
    }{<a href="$&">$&</a>}gsx;

    return $text;
}

1;

package Dancer::Plugin::Commentary::Format::Markdown;

use strict;
use warnings;

use Text::Markdown;

use parent 'Dancer::Plugin::Commentary::Format';

sub to_html {
    my ($text) = @_;

    return Text::Markdown::markdown($text);
}

1;

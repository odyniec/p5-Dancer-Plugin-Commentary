package Dancer::Plugin::Commentary::Auth;

use strict;
use warnings;

our %methods = ();

sub init { }

sub authentication_url { }

sub current_method_data {
    my ($class) = @_;

    for my $method (values %methods) {
        next if !$method->initialized;

        my $method_data = $method->method_data;

        if ($method_data->{authenticated}) {
            return $method_data;
        }
    }

    return;
}

1;

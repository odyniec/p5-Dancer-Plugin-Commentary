package Dancer::Plugin::Commentary::Storage;

use strict;
use warnings;

our %engines;

sub last_error {
    my ($self) = @_;

    return $self->{_last_error};
}

1;

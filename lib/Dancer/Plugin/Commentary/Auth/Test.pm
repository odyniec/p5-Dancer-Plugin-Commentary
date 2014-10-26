package Dancer::Plugin::Commentary::Auth::Test;

use strict;
use warnings;

use Dancer ':syntax';

use parent 'Dancer::Plugin::Commentary::Auth';

$Dancer::Plugin::Commentary::Auth::methods{test} = __PACKAGE__;

our $initialized = 0;

sub init {
    my ($class) = @_;

    $initialized = 1;

    return $class;
}

sub initialized {
    return $initialized;
}

sub method_data {
    my ($class) = @_;

    if (session('_test_auth_user')) {
        return session('_test_auth_user');
    }
}

1;

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

    my $data = {
        name                => 'Test',
        authenticated       => 0,
        authentication_url  => '',
        auth_data           => {},
    };

    if (session('_test_auth_user')) {
        $data->{authenticated} = 1;
        $data->{auth_data} = session('_test_auth_user');
    }

    return $data;
}

1;

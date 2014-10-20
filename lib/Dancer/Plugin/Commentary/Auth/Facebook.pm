package Dancer::Plugin::Commentary::Auth::Facebook;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Facebook;

use parent 'Dancer::Plugin::Commentary::Auth';

$Dancer::Plugin::Commentary::Auth::methods{facebook} = __PACKAGE__;

our $initialized = 0;

sub init {
    my ($class, $settings) = @_;

    if ($settings) {
        config->{plugins}{'Auth::Facebook'} = $settings;
    }

    warn 'No Dancer::Plugin::Auth::Facebook settings found'
        if !exists config->{plugins}{'Auth::Facebook'};

    $initialized = 1;

    return $class;
}

sub initialized {
    return $initialized;
}

sub authentication_url {
    my ($class, $callback_url) = @_;
}

sub method_data {
    my ($class, $callback_url) = @_;

    my $data = {
        name                => 'Facebook',
        authenticated       => 0,
        authentication_url  => '',
        auth_data           => {},
    };

    return $data;
}

1;

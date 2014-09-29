package Dancer::Plugin::Commentary::Auth::Facebook;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Facebook;

use parent 'Dancer::Plugin::Commentary::Auth';

$Dancer::Plugin::Commentary::Auth::methods{facebook} = __PACKAGE__;

sub init {
    my ($class, $settings) = @_;

    if ($settings) {
        config->{plugins}{'Auth::Facebook'} = $settings;
    }

    warn 'No Dancer::Plugin::Auth::Facebook settings found'
        if !exists config->{plugins}{'Auth::Facebook'};

    return $class;
}

sub authentication_url {
    my ($class, $callback_url) = @_;
}

sub auth_data {
    my ($class) = @_;

    if (session('fb_user')) {
        return {
            method => 'Facebook',
        };
    }
    else {
        return 0;
    }
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
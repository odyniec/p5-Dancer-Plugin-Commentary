package Dancer::Plugin::Commentary::Auth::Facebook;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Facebook;

use parent 'Dancer::Plugin::Commentary::Auth';

$Dancer::Plugin::Commentary::Auth::methods{facebook} = __PACKAGE__;

our $initialized = 0;

my $application_id;
my $application_secret;
my $scope;

sub init {
    my ($class, $settings) = @_;

    if ($settings) {
        config->{plugins}{'Auth::Facebook'} = $settings;
    }

    warn 'No Dancer::Plugin::Auth::Facebook settings found'
        if !exists config->{plugins}{'Auth::Facebook'};

    if (!exists config->{plugins}{'Auth::Facebook'}{callback_url}) {
        config->{plugins}{'Auth::Facebook'}{callback_url} =
            '//' . config->{server} . 
                (config->{port} != 80 ? ':' . config->{port} : '') .
                '/commentary/auth/facebook/callback';
    }

    auth_fb_init;

    $application_id = config->{plugins}{'Auth::Facebook'}{application_id};
    $application_secret =
        config->{plugins}{'Auth::Facebook'}{application_secret};
    $scope = config->{plugins}{'Auth::Facebook'}{scope} || '';

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

    if (session('fb_user')) {
        $data->{authenticated} = 1;
        $data->{auth_data}{name} = session('fb_user')->{name};
        $data->{auth_data}{url} = session('fb_user')->{link};
        $data->{auth_data}{avatar_url} = 'http://graph.facebook.com/' .
            session('fb_user')->{id} . '/picture';
    }
    else {
        $data->{authentication_url} = '' .
            $class->authentication_url($callback_url);
    }

    return $data;
}

1;

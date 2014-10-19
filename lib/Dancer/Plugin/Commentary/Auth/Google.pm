package Dancer::Plugin::Commentary::Auth::Google;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Google;
use IO::Socket::SSL;
use URI;
use URI::Escape;

use parent 'Dancer::Plugin::Commentary::Auth';

$Dancer::Plugin::Commentary::Auth::methods{google} = __PACKAGE__;

my $furl;

sub init {
    my ($class, $settings) = @_;

    if ($settings) {
        config->{plugins}{'Auth::Google'} = $settings;
    }

    warn 'No Dancer::Plugin::Auth::Google settings found'
        if !exists config->{plugins}{'Auth::Google'};

    if (!exists config->{plugins}{'Auth::Google'}{callback_url}) {
        config->{plugins}{'Auth::Google'}{callback_url} =
            '//' . config->{server} . 
                (config->{port} != 80 ? ':' . config->{port} : '') .
                '/commentary/auth/google/callback';
    }

    auth_google_init();

    $furl = Furl->new(
        agent    => "Dancer-Plugin-Commentary-Auth-Google/",
        timeout  => 5,
        ssl_opts => {
            SSL_verify_mode => SSL_VERIFY_NONE(),
        },
    );

    return $class;    
}

sub authentication_url {
    my ($class, $callback_url) = @_;

    my $uri = URI->new('https://accounts.google.com/o/oauth2/auth');
    $uri->query_form(
        response_type => 'code',
        client_id     => config->{plugins}{'Auth::Google'}{client_id},
        redirect_uri  => uri_for('/commentary/auth/google/callback'),
        state         => $callback_url || request->uri,
        scope         => config->{plugins}{'Auth::Google'}{scope} || 'profile',
        access_type   => config->{plugins}{'Auth::Google'}{access_type} || 'online',
    );

    return $uri;
}

sub method_data {
    my ($class, $callback_url) = @_;

    my $data = {
        name                => 'Google',
        authenticated       => 0,
        authentication_url  => '',
        auth_data           => {},
    };

    if (session('google_user')) {
        $data->{authenticated} = 1;
        $data->{auth_data}{name} = session('google_user')->{displayName};
        $data->{auth_data}{url} = session('google_user')->{url};
        # FIXME: The image might not exist -- check first
        $data->{auth_data}{avatar_url} = session('google_user')->{image}{url};
    }
    else {
        $data->{authentication_url} = '' .
            $class->authentication_url($callback_url);
    }

    return $data;
}

get '/commentary/auth/google/callback' => sub {
    return redirect '/auth/google/failed' if params->{'error'};
 
    my $code = params->{'code'};
    return redirect '/auth/google/failed' unless $code;
 
    my $res = $furl->post(
        'https://accounts.google.com/o/oauth2/token',
        [ 'Content-Type' => 'application/x-www-form-urlencoded' ],
        {
            code          => $code,
            client_id     => config->{plugins}{'Auth::Google'}{client_id},
            client_secret => config->{plugins}{'Auth::Google'}{client_secret},
            redirect_uri  => uri_for('/commentary/auth/google/callback'),
            grant_type    => 'authorization_code',
        }
    );
    my $data = from_json($res->decoded_content);
 
    return send_error 'google auth: no access token present'
        unless $data->{access_token};
 
    $res = $furl->get(
        'https://www.googleapis.com/plus/v1/people/me',
        [ 'Authorization' => 'Bearer ' . $data->{access_token} ],
    );
    my $user = from_json($res->decoded_content);
 
    # we need to stringify our JSON::Bool data as some
    # session backends might have trouble storing objects.
    # we should be able to safely remove this once
    # https://github.com/PerlDancer/Dancer-Session-Cookie/pull/1
    # (or a similar solution) is merged.
    if (exists $user->{image} and exists $user->{image}{isDefault}) {
        $user->{image}{isDefault} = "$user->{image}{isDefault}";
    }
    if (exists $user->{isPlusUser}) {
        $user->{isPlusUser} = "$user->{isPlusUser}";
    }
    if (exists $user->{verified}) {
        $user->{verified} = "$user->{verified}";
    }

    session 'google_user' => { %$data, %$user };
    redirect uri_unescape(params('query')->{state}) || '/';
};

1;

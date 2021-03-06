package Dancer::Plugin::Commentary::Auth::Twitter;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Twitter;
use URI::Escape;

use parent 'Dancer::Plugin::Commentary::Auth';

$Dancer::Plugin::Commentary::Auth::methods{twitter} = __PACKAGE__;

our $initialized = 0;

sub init {
    my ($class, $settings) = @_;

    if ($settings) {
        config->{plugins}{'Auth::Twitter'} = $settings;
    }

    warn 'No Dancer::Plugin::Auth::Twitter settings found'
        if !exists config->{plugins}{'Auth::Twitter'};

    if (!exists config->{plugins}{'Auth::Twitter'}{callback_url}) {
        config->{plugins}{'Auth::Twitter'}{callback_url} =
            '//' . config->{server} . 
                (config->{port} != 80 ? ':' . config->{port} : '') .
                '/commentary/auth/twitter/callback';
    }

    auth_twitter_init();

    $initialized = 1;

    return $class;
}

sub initialized {
    return $initialized;
}

sub authentication_url {
    my ($class, $callback_url) = @_;

    my $url = twitter->get_authentication_url(
        'callback' => request->uri_base .
            '/commentary/auth/twitter/callback?callback=' .
                ($callback_url || uri_escape(request->uri_base . request->uri))
    );

    session request_token        => twitter->request_token;
    session request_token_secret => twitter->request_token_secret;
    session access_token         => '';
    session access_token_secret  => '';
 
    return $url;
}

sub method_data {
    my ($class, $callback_url) = @_;

    my $data = {
        name                => 'Twitter',
        authenticated       => 0,
        authentication_url  => '',
        auth_data           => {},
    };

    if (session('twitter_user')) {
        $data->{authenticated} = 1;
        $data->{auth_data}{unique_id} = session('twitter_user')->{screen_name};
        $data->{auth_data}{name} = session('twitter_user')->{name};
        $data->{auth_data}{url} = session('twitter_user')->{url};
        $data->{auth_data}{avatar_url} =
            session('twitter_user')->{profile_image_url};
    }
    else {
        $data->{authentication_url} = '' .
            $class->authentication_url($callback_url);
    }

    return $data;
}

# This is the same as Dancer::Plugin::Auth::Twitter's callback route, except it
# also supports passing a success callback URL in query string
get '/commentary/auth/twitter/callback' => sub {
    # A user denying access should be considered a failure
    return redirect config->{plugins}{'Auth::Twitter'}{callback_fail}
        if (params->{'denied'});
 
    if (   !session('request_token')
        || !session('request_token_secret')
        || !params->{'oauth_verifier'})
    {
        return send_error 'no request token present, or no verifier';
    }
 
    my $token               = session('request_token');
    my $token_secret        = session('request_token_secret');
    my $access_token        = session('access_token');
    my $access_token_secret = session('access_token_secret');
    my $verifier            = params->{'oauth_verifier'};
 
    if (!$access_token && !$access_token_secret) {
        twitter->request_token($token);
        twitter->request_token_secret($token_secret);
        ($access_token, $access_token_secret) = twitter->request_access_token('verifier' => $verifier);
 
        # this is in case we need to register the user after the oauth process
        session access_token        => $access_token;
        session access_token_secret => $access_token_secret;
    }
 
    # get the user
    twitter->access_token($access_token);
    twitter->access_token_secret($access_token_secret);
 
    my $twitter_user_hash;
    eval {
        $twitter_user_hash = twitter->verify_credentials();
    };
 
    if ($@ || !$twitter_user_hash) {
        Dancer::Logger::core("no twitter_user_hash or error: ".$@);
        return redirect config->{plugins}{'Auth::Twitter'}{callback_fail};
    }
 
    $twitter_user_hash->{'access_token'} = $access_token;
    $twitter_user_hash->{'access_token_secret'} = $access_token_secret;
 
    # save the user
    session 'twitter_user'                => $twitter_user_hash;
    session 'twitter_access_token'        => $access_token,
    session 'twitter_access_token_secret' => $access_token_secret,
 
    redirect params('query')->{callback} ||
        config->{plugins}{'Auth::Twitter'}{callback_success};
};

1;

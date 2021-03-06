package Dancer::Plugin::Commentary::Auth::Github;

use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Plugin::Auth::Github;
use Digest::SHA qw(sha256_hex);
use JSON qw(decode_json);
use LWP::UserAgent;
use URI::Escape;

use parent 'Dancer::Plugin::Commentary::Auth';

$Dancer::Plugin::Commentary::Auth::methods{github} = __PACKAGE__;

our $initialized = 0;

my $client_id;
my $client_secret;
my $scope;
my $state_salt = join '', map { sprintf '%x', rand(16) } 1..20;

sub init {
    my ($class, $settings) = @_;

    if ($settings) {
        config->{plugins}{'Auth::Github'} = $settings;
    }

    warn 'No Dancer::Plugin::Auth::Github settings found'
        if !exists config->{plugins}{'Auth::Github'};

    auth_github_init;

    $client_id = config->{plugins}{'Auth::Github'}{client_id};
    $client_secret = config->{plugins}{'Auth::Github'}{client_secret};
    $scope = config->{plugins}{'Auth::Github'}{scope} || '';

    $initialized = 1;

    return $class;
}

sub initialized {
    return $initialized;
}

sub authentication_url {
    my ($class, $callback_url) = @_;

    my $generate_state = sha256_hex($client_id.$client_secret.$state_salt);

    return 'https://github.com/login/oauth/authorize/?' .
        "client_id=$client_id&scope=$scope&state=$generate_state" .
        '&redirect_uri=' .
            uri_escape(request->uri_base .
                '/commentary/auth/github/callback?callback=' .
                    ($callback_url || uri_escape(request->uri_base . request->uri)));
}

sub method_data {
    my ($class, $callback_url) = @_;

    my $data = {
        name                => 'Github',
        authenticated       => 0,
        authentication_url  => '',
        auth_data           => {},
    };

    if (session('github_user')) {
        $data->{authenticated} = 1;
        $data->{auth_data}{name} = session('github_user')->{name};
        $data->{auth_data}{url} = session('github_user')->{html_url};
        $data->{auth_data}{avatar_url} = session('github_user')->{avatar_url};
    }
    else {
        $data->{authentication_url} = '' .
            $class->authentication_url($callback_url);
    }

    return $data;
}

# This is the same as Dancer::Plugin::Auth::Github's callback route, except it
# also supports passing a success callback URL in query string
get '/commentary/auth/github/callback' => sub {
    my $generate_state = sha256_hex($client_id.$client_secret.$state_salt);
    my $state_received = params->{'state'};

    if ($state_received eq $generate_state) {
        my $code = params->{'code'};
        my $browser = LWP::UserAgent->new;
        my $resp = $browser->post('https://github.com/login/oauth/access_token/', [
            client_id       => $client_id,
            client_secret   => $client_secret,
            code            => $code,
            state           => $state_received,
        ]);
        
        die "error while fetching: ", $resp->status_line
            unless $resp->is_success;
         
        my %querystr = Dancer::Plugin::Auth::Github::parse_query_str(
            $resp->decoded_content);
        my $acc = $querystr{access_token};
         
        if ($acc) {
            my $jresp  = $browser->get("https://api.github.com/user?access_token=$acc");
            my $json = decode_json($jresp->decoded_content);
            session 'github_user' => $json;
            session 'github_access_token' => $acc;
            redirect params('query')->{callback} || '/';
            return;
        }
    }

    redirect '/auth/github/failed';
};

1;

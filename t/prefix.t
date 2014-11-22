use strict;
use warnings;

use Dancer ':syntax';
use HTTP::Request::Common qw( GET POST PUT DELETE );
use Plack::Test;
use Test::More import => [ '!pass' ];

{
    package TestApp;

    use Dancer ':syntax';

    BEGIN {
        set plugins => {
            'Commentary' => {
                prefix => '/foo',
            }
        };
    }

    use Dancer::Plugin::Commentary;

    get '/other' => sub {
        return 42;
    };
}

my $res;

my $app  = Dancer::Handler->psgi_app;
my $test = Plack::Test->create($app);

$res = $test->request(GET '/foo/comments');
is($res->code, 200, 'Response is "200 OK" for a route with prefix');

$res = $test->request(GET '/foo/assets/js/commentary.js');
is($res->code, 200, 'Response is "200 OK" for an assets route with prefix');

$res = $test->request(GET '/other');
is($res->code, 200, 'Response is "200 OK" for a non-plugin route');

$res = $test->request(GET '/commentary/comments');
is($res->code, 404,
    'Response is "404 Not Found" for a route with the default prefix');

done_testing;

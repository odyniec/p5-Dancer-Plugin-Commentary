use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Test;
use Test::More import => [ '!pass' ];

{
    package TestApp;

    use Dancer ':syntax';

    BEGIN {
        set plugins => {
            'Commentary' => {
                prefix => '/foo',
            }
        }
    }

    use Dancer::Plugin::Commentary;

    get '/other' => sub {
        return 42;
    };
}

response_status_is(
    [ POST => '/foo/search/comments' ],
    200,
    'Response is "200 OK" for a route with prefix'
);

response_status_is(
    [ GET => '/other' ],
    200,
    'Response is "200 OK" for a non-plugin route'
);

response_status_is(
    [ POST => '/commentary/search/comments' ],
    404,
    'Response is "404 Not Found" for a route with the default prefix'
);

done_testing;

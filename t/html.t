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
            'Commentary' => {}
        }
    }

    use Dancer::Plugin::Commentary;
}

my $res;

get '/body.html' => sub {
    content_type 'text/html';
    return '<html><head></head><body></body></html>';
};

get '/not-really-html.txt' => sub {
    content_type 'text/plain';
    return '<html><head></head><body></body></html>';
};

$res = dancer_response(GET => '/body.html');
like($res->content, qr{ __commentaryCfg }x,
    'A text/html file with <body> gets processed');

$res = dancer_response(GET => '/not-really-html.txt');
unlike($res->content, qr{ __commentaryCfg }x,
    'A non-text/html file with <body> does not get processed');

done_testing;

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
my $res_data;

$res = dancer_response(GET => '/commentary/comments/');
is($res->status, 200, 'Response is successful');
$res_data = from_json $res->content;
is_deeply($res_data, [], 'Response is an empty arrayref');

done_testing;

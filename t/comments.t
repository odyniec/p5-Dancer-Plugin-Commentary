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

# Post a new comment

my %valid_comment_data = (
    body        => 'This is a comment',
    post_url    => '/foo.html',
);

$res = dancer_response(POST => '/commentary/comments',
    { params => \%valid_comment_data });
is($res->status, 201, 'Response is "201 Created"');
is($res->header('location'),
    uri_for ('/commentary/comments/' . $valid_comment_data{post_url}),
    'The expected location header is returned');
$res_data = from_json $res->content;
ok(delete $res_data->{timestamp} <= time, 'Expected timestamp is returned');
is_deeply(delete $res_data->{author}, {}, 'Author data is empty as expected');
is_deeply($res_data, \%valid_comment_data,
    'The data in the response matches what was posted');

# Attempt to post a new comment with empty body

$res = dancer_response(POST => '/commentary/comments',
    { params => { post_url => '/foo.html', body => '' } });
is($res->status, 422, 'Response is "422 Unprocessable Entity"');
$res_data = from_json $res->content;
is(scalar @$res_data, 1, 'One error is returned');
is($res_data->[0]{code}, 'params.body.empty',
    'The correct error code is returned');

done_testing;

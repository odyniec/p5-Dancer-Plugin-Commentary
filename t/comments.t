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
                auth => {
                    methods => {
                        test => {}
                    }
                }
            }
        }
    }

    use Dancer::Plugin::Commentary;
}

my $res;
my $res_data;

session('_test_auth_user', {
    unique_id         => 'test',
    name              => 'Bobby Testington',
    url               => 'http://foo.bar',
    profile_image_url => 'http://foo.bar/baz.png',
});

subtest 'Retrieve an empty list of comments' =>
sub {
    $res = dancer_response(POST => '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->status, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is_deeply($res_data, [], 'An empty list is returned');
};

my %valid_comment_data = (
    body     => 'This is a comment',
    post_url => '/foo.html',
    extra    => {},
);

my %expected_comment_data = (
    %valid_comment_data,
    author => {
        auth_method => 'Test',
        %{ session('_test_auth_user') },
    }
);

subtest 'Post a new comment' =>
sub {
    $res = dancer_response(POST => '/commentary/comments',
        { body => to_json \%valid_comment_data });
    is($res->status, 201, 'Response is "201 Created"');
    is($res->header('location'),
        uri_for('/commentary/comments/1'),
        'The expected location header is returned');
    $res_data = from_json $res->content;
    is(delete $res_data->{id}, 1, 'Expected ID is returned');
    ok(delete $res_data->{created_timestamp} <= time,
        'Expected creation timestamp is returned');
    is(delete $res_data->{updated_timestamp}, undef,
        'Update timestamp is not defined');
    is_deeply($res_data, \%expected_comment_data,
        'The remaining data in the response matches what was posted');
};

subtest 'Attempt to post a new comment with empty body' =>
sub {
    $res = dancer_response(POST => '/commentary/comments', {
        body => to_json {
            post_url => '/foo.html',
            author => { name => 'Foo' },
            body => ''
        }
    });
    is($res->status, 422, 'Response is "422 Unprocessable Entity"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One error is returned');
    is($res_data->[0]{code}, 'params.body.empty',
        'The correct error code is returned');
};

subtest 'Retrieve the newly posted comment' =>
sub {
    $res = dancer_response(GET => '/commentary/comments/1');
    is($res->status, 200, 'Response is "200 OK"');
};

subtest 'Attempt to retrieve a nonexisting comment' =>
sub {
    $res = dancer_response(GET => '/commentary/comments/2');
    is($res->status, 404, 'Response is "404 Not Found"');
};

subtest 'Search for the newly posted comment' =>
sub {
    $res = dancer_response(POST => '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->status, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One comment is returned');
    is($res_data->[0]{body}, $valid_comment_data{body},
        'The expected comment body is returned');
};

subtest 'Update the comment' =>
sub {
    $res = dancer_response(PATCH => '/commentary/comments/1', {
        body => to_json { body => 'I changed my mind.' },
    });
    is($res->status, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is($res_data->{body}, 'I changed my mind.',
        'The expected updated comment body is returned');
    ok(defined $res_data->{updated_timestamp}, 'Update timestamp is defined');
};

subtest 'Attempt to update with empty body' =>
sub {
    $res = dancer_response(PATCH => '/commentary/comments/1', {
        body => to_json { body => '' },
    });
    is($res->status, 422, 'Response is "422 Unprocessable Entity"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One error is returned');
    is($res_data->[0]{code}, 'params.body.empty',
        'The correct error code is returned');
};

subtest 'Attempt to update a restricted field' =>
sub {
    $res = dancer_response(PATCH => '/commentary/comments/1', {
        body => to_json { created_timestamp => 123 },
    });
    $res_data = from_json $res->content;
    isnt($res_data->{created_timestamp}, 123, 'The value is not changed');
};

subtest 'Post a second comment' =>
sub {
    $res = dancer_response(POST => '/commentary/comments',
        { body => to_json \%valid_comment_data });
    is($res->status, 201, 'Response is "201 Created"');
    is($res->header('location'),
        uri_for('/commentary/comments/2'),
        'The expected location header is returned');
    $res_data = from_json $res->content;
    is(delete $res_data->{id}, 2, 'Expected ID is returned');
    ok(delete $res_data->{created_timestamp} <= time,
        'Expected creation timestamp is returned');
    ok(delete $res_data->{updated_timestamp} <= time,
        'Expected update timestamp is returned');
    is_deeply($res_data, \%expected_comment_data,
        'The remaining data in the response matches what was posted');
};

subtest 'Retrieve the two comments' =>
sub {
    $res = dancer_response(POST => '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->status, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 2, 'Two comments are returned');
    is_deeply([ sort(map { $_->{id} } @$res_data) ], [ 1, 2 ],
        'The returned comments have the expected IDs');
};

subtest 'Remove the first comment' =>
sub {
    $res = dancer_response(DELETE => '/commentary/comments/1');
    is($res->status, 204, 'Response is "204 No Content"');
    is($res->content, '', 'Reponse content is empty');
};

subtest 'Retrieve comments after one was deleted' =>
sub {
    $res = dancer_response(POST => '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->status, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One comment is returned');
    is($res_data->[0]{id}, 2, 'The returned comment has the expected ID');
};

subtest 'Attempt to retrieve a removed comment' =>
sub {
    $res = dancer_response(GET => '/commentary/comments/1');
    is($res->status, 404, 'Response is "404 Not Found"');
};

subtest 'Attempt to remove an already removed comment' =>
sub {
    $res = dancer_response(DELETE => '/commentary/comments/1');
    is($res->status, 404, 'Response is "404 Not Found"');
};

done_testing;

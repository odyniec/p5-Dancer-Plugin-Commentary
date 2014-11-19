use strict;
use warnings;

use Dancer ':syntax';
use HTTP::Request::Common qw( GET POST PUT DELETE );
use Plack::Test;
use Test::More import => [ '!pass' ];

my $user_data;

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
        };
        set session => 'simple';
    }

    use Dancer::Plugin::Commentary;

    hook before => sub {
        session('_test_auth_user', $user_data = {
            unique_id         => 'test',
            name              => 'Bobby Testington',
            url               => 'http://foo.bar',
            profile_image_url => 'http://foo.bar/baz.png',
        });
    };
}

my $res;
my $res_data;

my $app  = Dancer::Handler->psgi_app;
my $test = Plack::Test->create($app);
 
subtest 'Retrieve an empty list of comments' =>
sub {
    $res = $test->request(GET '/commentary/comments');
    is($res->code, 200, 'Response is "200 OK"');
    is_deeply(from_json($res->content), [], 'An empty list is returned');
};

subtest 'Search for an empty list of comments' =>
sub {
    $res = $test->request(POST '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->code, 200, 'Response is "200 OK"');
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
        %$user_data,
    }
);

subtest 'Post a new comment' =>
sub {
    $res = $test->request(POST '/commentary/comments',
        Content => to_json \%valid_comment_data);
    is($res->code, 201, 'Response is "201 Created"');
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
    $res = $test->request(POST '/commentary/comments',
        Content => to_json {
            post_url => '/foo.html',
            author => { name => 'Foo' },
            body => ''
        }
    );
    is($res->code, 422, 'Response is "422 Unprocessable Entity"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One error is returned');
    is($res_data->[0]{code}, 'params.body.empty',
        'The correct error code is returned');
};

subtest 'Retrieve the newly posted comment' =>
sub {
    $res = $test->request(GET '/commentary/comments/1');
    is($res->code, 200, 'Response is "200 OK"');
};

subtest 'Attempt to retrieve a nonexisting comment' =>
sub {
    $res = $test->request(GET '/commentary/comments/2');
    is($res->code, 404, 'Response is "404 Not Found"');
};

subtest 'Search for the newly posted comment' =>
sub {
    $res = $test->request(POST '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->code, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One comment is returned');
    is($res_data->[0]{body}, $valid_comment_data{body},
        'The expected comment body is returned');
};

subtest 'Update the comment' =>
sub {
    $res = $test->request(
        HTTP::Request->new(
            'PATCH', '/commentary/comments/1',
            [],
            to_json { body => 'I changed my mind.' }
        )
    );
    is($res->code, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is($res_data->{body}, 'I changed my mind.',
        'The expected updated comment body is returned');
    ok(defined $res_data->{updated_timestamp}, 'Update timestamp is defined');
};

subtest 'Attempt to update with empty body' =>
sub {
    $res = $test->request(
        HTTP::Request->new(
            'PATCH', '/commentary/comments/1',
            [],
            to_json { body => '' }
        )
    );
    is($res->code, 422, 'Response is "422 Unprocessable Entity"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One error is returned');
    is($res_data->[0]{code}, 'params.body.empty',
        'The correct error code is returned');
};

subtest 'Attempt to update a restricted field' =>
sub {
    $res = $test->request(
        HTTP::Request->new(
            'PATCH', '/commentary/comments/1',
            [],
            to_json { created_timestamp => 123 }
        )
    );
    $res_data = from_json $res->content;
    isnt($res_data->{created_timestamp}, 123, 'The value is not changed');
};

subtest 'Post a second comment' =>
sub {
    $res = $test->request(POST '/commentary/comments',
        Content => to_json \%valid_comment_data);
    is($res->code, 201, 'Response is "201 Created"');
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
    $res = $test->request(GET '/commentary/comments');
    is($res->code, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 2, 'Two comments are returned');
    is_deeply([ sort(map { $_->{id} } @$res_data) ], [ 1, 2 ],
        'The returned comments have the expected IDs');
};

subtest 'Search for the two comments' =>
sub {
    $res = $test->request(POST '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->code, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 2, 'Two comments are returned');
    is_deeply([ sort(map { $_->{id} } @$res_data) ], [ 1, 2 ],
        'The returned comments have the expected IDs');
};

subtest 'Remove the first comment' =>
sub {
    $res = $test->request(DELETE '/commentary/comments/1');
    is($res->code, 204, 'Response is "204 No Content"');
    is($res->content, '', 'Reponse content is empty');
};

subtest 'Retrieve comments after one was deleted' =>
sub {
    $res = $test->request(POST '/commentary/search/comments',
        { post_url => '/foo.html' });
    is($res->code, 200, 'Response is "200 OK"');
    $res_data = from_json $res->content;
    is(scalar @$res_data, 1, 'One comment is returned');
    is($res_data->[0]{id}, 2, 'The returned comment has the expected ID');
};

subtest 'Attempt to retrieve a removed comment' =>
sub {
    $res = $test->request(GET '/commentary/comments/1');
    is($res->code, 404, 'Response is "404 Not Found"');
};

subtest 'Attempt to remove an already removed comment' =>
sub {
    $res = $test->request(DELETE '/commentary/comments/1');
    is($res->code, 404, 'Response is "404 Not Found"');
};

done_testing;

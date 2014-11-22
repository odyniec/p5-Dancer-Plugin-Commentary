use strict;
use warnings;

use Dancer ':syntax';
use HTTP::Request::Common qw( GET POST PUT DELETE );
use Plack::Test;
use Test::More import => [ '!pass' ];

my $logged_in_user;

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
                },
                admins => 'test:admin',
            }
        };
        set session => 'simple';
    }

    my %users = (
        admin => {
            unique_id         => 'admin',
            name              => 'Adam McAdmin',
            url               => 'http://foo.bar',
            profile_image_url => 'http://foo.bar/baz.png',
        },
        alice => {
            unique_id         => 'alice',
            name              => 'Alice Testington',
            url               => 'http://foo.bar',
            profile_image_url => 'http://foo.bar/baz.png',
        },
        bob => {
            unique_id         => 'bob',
            name              => 'Robert Testerson',
            url               => 'http://foo.bar',
            profile_image_url => 'http://foo.bar/baz.png',        
        },
    );

    hook before => sub {
        session('_test_auth_user', $users{$logged_in_user});
    };

    use Dancer::Plugin::Commentary;
}

my $res;

my $app  = Dancer::Handler->psgi_app;
my $test = Plack::Test->create($app);

$logged_in_user = 'alice';

my $comment_uri;

$res = $test->request(POST '/commentary/comments',
    Content => to_json { post_url => '/foo.html', body => 'Frist!!!!1' });
is($res->code, 201, 'Response is "201 Created"');
$comment_uri = $res->header('location');

$res = $test->request(DELETE $comment_uri);
is($res->code, 204, 'Comment can be deleted by author');

$res = $test->request(POST '/commentary/comments',
    Content => to_json { post_url => '/foo.html', body => 'Frist!!!!1' });
is($res->code, 201, 'Response is "201 Created"');
$comment_uri = $res->header('location');

$logged_in_user = 'bob';

$res = $test->request(DELETE $comment_uri);
is($res->code, 401, 'Comment can not be deleted by another user');

$logged_in_user = 'admin';

$res = $test->request(DELETE $comment_uri);
is($res->code, 204, 'Comment can be deleted by administrator');

done_testing;

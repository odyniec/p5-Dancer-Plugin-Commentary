use strict;
use warnings;

use Dancer ':syntax';
use Dancer::Test;
use DBI;
use File::Temp;
use Test::Deep;
use Test::More;

my $tmpdb = File::Temp->new(EXLOCK => 0);
my $dsn = "dbi:SQLite:dbname=" . $tmpdb->filename;
my $dbh = DBI->connect($dsn , "", "");

sub all_comments {
    my $sth = $dbh->prepare(qq{ SELECT * FROM comments });
    $sth->execute;

    return $sth->fetchall_arrayref({});
}

# Create the comments table
$dbh->do(qq{
    CREATE TABLE comments (
        id                INTEGER PRIMARY KEY,
        created_timestamp BIGINT,
        updated_timestamp BIGINT,
        body              TEXT,
        post_url          TEXT,
        author_json       TEXT,
        extra_json        TEXT
    );
});

use_ok('Dancer::Plugin::Commentary::Storage::DBI');

my $storage = Dancer::Plugin::Commentary::Storage::DBI->new({
    dsn      => $dsn,
    user     => "",
    password => "",
});

is_deeply(all_comments, [], 'Comments table is empty');

my @comment_data = (
    {
        post_url => 'http://some.url/post.html',
        body     => 'Interesting comment',
        author   => { author_data => { } },
        extra    => { extra_data => { } },
    },
    {
        post_url => 'http://some.url/post.html',
        body     => 'Even more interesting comment',
        author   => { author_data => { } },
        extra    => { extra_data => { } },
    },
);

my $comment1 = $storage->add($comment_data[0]);

like($comment1->{id}, qr/^[1-9]\d*$/, 'Comment ID is a positive number');
is(scalar @{all_comments()}, 1, 'There is one record in the comments table');
cmp_deeply($storage->get({ post_url => $comment_data[0]->{post_url} })->[0],
    superhashof($comment_data[0]), 'The expected comment data is returned');

my $comment2 = $storage->add($comment_data[1]);

is(scalar @{all_comments()}, 2, 'There are two records in the comments table');
cmp_bag($storage->get({ post_url => $comment_data[0]->{post_url} }),
    [ superhashof($comment_data[0]), superhashof($comment_data[1]) ],
    'Data for both comments is returned');

# Updated comment data
$comment_data[1]->{body} = 'I changed my mind';
$comment_data[1]->{author}{author_data} = { foo => 'bar' };

$comment2 = $storage->update({ id => $comment2->{id}, %{$comment_data[1]} });

cmp_deeply($storage->get({ id => $comment2->{id} })->[0],
    superhashof($comment_data[1]),
    'The expected updated comment data is returned');

is($storage->remove($comment1->{id}), 1,
    'First comment is removed successfully');
is(scalar @{all_comments()}, 1,
    'There is one record left in the comments table');
is_deeply($storage->get({ id => $comment1->{id} }), [],
    'Removed comment data is not returned');

is($storage->remove($comment1->{id}), 0,
    'Attempting to remove the same comment again fails');
is($storage->last_error->{code}, 'storage.dbi.comment_not_found',
    'The expected error is reported');

# Make sure last_error will be set again
$storage->{_last_error} = undef;

is($storage->update($comment1), 0,
    'Attempting to update a removed comment fails');
is($storage->last_error->{code}, 'storage.dbi.comment_not_found',
    'The expected error is reported');

done_testing;

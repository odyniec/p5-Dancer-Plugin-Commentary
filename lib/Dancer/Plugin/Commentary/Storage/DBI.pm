package Dancer::Plugin::Commentary::Storage::DBI;

use strict;
use warnings;

use Dancer qw(from_json to_json);
use DBI;

use parent 'Dancer::Plugin::Commentary::Storage';

$Dancer::Plugin::Commentary::Storage::engines{dbi} = __PACKAGE__;

sub new {
    my ($class, $settings) = @_;

    my $self = {
        _settings => $settings,
    };

    return bless $self, $class;
}

sub init {
    my ($self) = @_;
}

sub add {
    my ($self, $comment) = @_;

    my $new_comment = { %$comment };

    my $quoted_table = $self->_quoted_table;

    my $sth = $self->_dbh->prepare(qq{
        INSERT INTO $quoted_table (created_timestamp, updated_timestamp, body,
            post_url, author_json, extra_json)
            VALUES (?, ?, ?, ?, ?, ?)
    });

    my $time = time;
 
    $sth->execute($time, $time, $comment->{body}, $comment->{post_url},
        to_json($comment->{author}, { pretty => 0 }),
        to_json($comment->{extra}, { pretty => 0 }));
    $self->_dbh->commit() unless $self->_dbh->{AutoCommit};

    # FIXME: Handle errors

    $new_comment->{id} = $self->_dbh->last_insert_id((undef) x 4);

    return $new_comment;
}

sub get {
    my ($self, $cond) = @_;

    my $where_sql = '';
    my @where_fields;
    my @where_values;

    if (%$cond) {
        for my $field (keys %$cond) {
            push @where_fields, "$field = ?";
            push @where_values, $cond->{$field};
        }

        $where_sql = 'WHERE ' . join ' AND ', @where_fields;
    }

    my $quoted_table = $self->_quoted_table;

    my $sth = $self->_dbh->prepare(qq{
        SELECT * FROM $quoted_table
        $where_sql
    });

    $sth->execute(@where_values);
    
    return [ map { {
        id                => $_->{id},
        created_timestamp => $_->{created_timestamp},
        updated_timestamp => $_->{updated_timestamp},
        post_url          => $_->{post_url},
        body              => $_->{body},
        author            => from_json($_->{author_json}),
        extra             => from_json($_->{extra_json}),
    } } @{$sth->fetchall_arrayref({})} ];
}

sub update {
    my ($self, $comment) = @_;

    my $quoted_table = $self->_quoted_table;

    my $sth = $self->_dbh->prepare(qq{
        SELECT * FROM $quoted_table
        WHERE id = ?
    });

    $sth->execute($comment->{id});

    my $record = $sth->fetchrow_hashref;

    if (!defined $record) {
        $self->{_last_error} = {
            code => 'storage.dbi.comment_not_found',
            msg  => 'Comment not found',
        };
    }

    $sth = $self->_dbh->prepare(qq{
        UPDATE $quoted_table SET
            updated_timestamp = ?,
            body = ?
            WHERE id = ?
    });

    my $time = time;
 
    $sth->execute($time, $comment->{body}, $comment->{id});
    $self->_dbh->commit() unless $self->_dbh->{AutoCommit};

    # FIXME: Handle errors

    # TODO: Return updated comment data

    return $comment;
}

sub _dbh {
    my ($self) = @_;

    # Is there an existing connection?
    return $self->{_dbh} if defined $self->{_dbh};

    # We might have been given a dbh in the settings 
    return $self->{_dbh} = $self->{_settings}{dbh}->()
        if defined $self->{_settings}{dbh};

    DBI->parse_dsn($self->{_settings}{dsn} || '')
        or die 'No valid DSN specified';
 
    if (!defined $self->{_settings}{user} ||
        !defined $self->{_settings}{password})
    {
        die 'No database user or password specified';
    }
 
    # Establish a new connection to the database
    $self->{_dbh} = DBI->connect($self->{_settings}{dsn},
        $self->{_settings}{user}, $self->{_settings}{password});

    if ('mysql' eq lc $self->{_dbh}{Driver}{Name}) {
        # Automatically re-establish connection if it's lost
        $self->{_dbh}{mysql_auto_reconnect} = 1;
    }

    return $self->{_dbh};
}

sub _quoted_table {
    my ($self) = @_;

    return $self->{_quoted_table} ||=
        $self->_dbh->quote_identifier($self->{_settings}{table} || 'comments');
}

1;

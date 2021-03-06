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

    my @comment_fields = qw(
        author_json
        body
        body_html
        created_timestamp
        extra_json
        format
        post_url
        updated_timestamp
    );
    my $field_names = join ',', @comment_fields;
    my $placeholders = join ',', ('?') x ($#comment_fields + 1);

    my $sth = $self->_dbh->prepare(qq{
        INSERT INTO $quoted_table ($field_names) VALUES ($placeholders)
    });

    my @comment_data = map {
        if ($_ =~ /^(.*?)_json$/) {
            # JSON data field
            to_json($comment->{$1}, { pretty => 0 });
        }
        else {
            $comment->{$_};
        }
    } @comment_fields;

    $sth->execute(@comment_data);
    $self->_dbh->commit() unless $self->_dbh->{AutoCommit};

    # FIXME: Handle errors

    $new_comment->{id} = $self->_dbh->last_insert_id((undef) x 4);

    return $new_comment;
}

sub get {
    my ($self, $cond) = @_;

    $cond //= {};

    my $where_sql = '';
    my @where_fields;
    my @where_values;

    # If there's no condition for the "deleted" field, assume comments with the
    # deleted flag set aren't supposed to be returned.
    if (!exists $cond->{deleted}) {
        $cond->{deleted} = 0;
    }

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
        author            => from_json($_->{author_json}),
        body              => $_->{body},
        body_html         => $_->{body_html},
        created_timestamp => $_->{created_timestamp},
        extra             => from_json($_->{extra_json}),
        post_url          => $_->{post_url},
        updated_timestamp => $_->{updated_timestamp},
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
        return;
    }

    my $updated_comment = {
        %$record,
        %$comment,
    };

    $sth = $self->_dbh->prepare(qq{
        UPDATE $quoted_table SET
            author_json       = ?,
            body              = ?,
            extra_json        = ?,
            post_url          = ?,
            updated_timestamp = ?
            WHERE id = ?
    });

    $sth->execute(to_json($updated_comment->{author}, { pretty => 0 }),
        $updated_comment->{body},
        to_json($updated_comment->{extra}, { pretty => 0 }),
        $updated_comment->{post_url}, $updated_comment->{updated_timestamp},
        $updated_comment->{id});
    $self->_dbh->commit() unless $self->_dbh->{AutoCommit};

    # FIXME: Handle errors

    return $updated_comment;
}

sub remove {
    my ($self, $id) = @_;

    my $quoted_table = $self->_quoted_table;

    my $sth = $self->_dbh->prepare(qq{
        SELECT * FROM $quoted_table
        WHERE id = ?
    });

    $sth->execute($id);

    if (!defined $sth->fetchrow_hashref) {
        $self->{_last_error} = {
            code => 'storage.dbi.comment_not_found',
            msg  => 'Comment not found',
        };
        return;
    }

    $sth = $self->_dbh->prepare(qq{
        DELETE FROM $quoted_table WHERE id = ?
    });

    $sth->execute($id);
    $self->_dbh->commit() unless $self->_dbh->{AutoCommit};

    # FIXME: Handle errors

    return 1;
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

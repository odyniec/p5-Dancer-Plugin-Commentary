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

    my $quoted_table = $self->_quoted_table;

    my $sth = $self->_dbh->prepare(qq{
        INSERT INTO $quoted_table (timestamp, body, post_url, author_json)
            VALUES (?, ?, ?, ?)
    });
 
    $sth->execute(time, $comment->{body}, $comment->{post_url},
        to_json($comment->{author}, { pretty => 0 }));
    $self->_dbh->commit() unless $self->_dbh->{AutoCommit};

    # FIXME: Handle errors

    return $comment;
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
        timestamp   => $_->{timestamp},
        post_url    => $_->{post_url},
        body        => $_->{body},
        author      => from_json($_->{author_json}),
    } } @{$sth->fetchall_arrayref({})} ];
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
    return $self->{_dbh} = DBI->connect($self->{_settings}{dsn},
        $self->{_settings}{user}, $self->{_settings}{password});
}

sub _quoted_table {
    my ($self) = @_;

    return $self->{_quoted_table} ||=
        $self->_dbh->quote_identifier($self->{_settings}{table} || 'comments');
}

1;

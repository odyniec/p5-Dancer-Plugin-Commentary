package Dancer::Plugin::Commentary::Storage::Memory;

use strict;
use warnings;

use parent 'Dancer::Plugin::Commentary::Storage';

$Dancer::Plugin::Commentary::Storage::engines{memory} = __PACKAGE__;

sub new {
    my ($class) = @_;

    my $self = {
        _comments =>  {},
    };

    return bless $self, $class;
}

sub init { }

sub add {
    my ($self, $comment) = @_;

    $self->{_comments}{my $id = 1 + keys %{$self->{_comments}}} = $comment;

    return {
        id => $id,
        %$comment
    };
}

sub get {
    my ($self, $cond) = @_;

    # If there's no condition for the "deleted" field, assume comments with the
    # deleted flag set aren't supposed to be returned.
    if (!%$cond || !exists $cond->{deleted}) {
        $cond->{deleted} = 0;
    }

    return [
        grep {
            eval {
                for my $field (keys %$cond) {
                    return 0 if ($_->{$field} ne $cond->{$field});
                }
                return 1;
            }
        } 
        map {
            {
                id => $_,
                %{$self->{_comments}{$_}}
            }
        }
        grep { defined $self->{_comments}{$_} }
        keys %{$self->{_comments}}
    ];
}

sub update {
    my ($self, $comment) = @_;

    if (defined $self->{_comments}{$comment->{id}}) {
        $self->{_comments}{$comment->{id}} = $comment;
    }
    else {
        $self->{_last_error} = {
            code => 'storage.memory.comment_not_found',
            msg => 'Comment not found',
        };
        return;        
    }

    return $comment;
}

sub remove {
    my ($self, $id) = @_;

    if (defined $self->{_comments}{$id}) {
        $self->{_comments}{$id} = undef;
        return 1;
    }
    else {
        $self->{_last_error} = {
            code => 'storage.memory.comment_not_found',
            msg => 'Comment not found',
        };
        return;
    }
}

1;

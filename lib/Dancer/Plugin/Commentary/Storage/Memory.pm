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
        keys %{$self->{_comments}}
    ];
}

sub remove {
    my ($self, $id) = @_;

    if (delete $self->{_comments}{$id}) {
        return 1;
    }
    else {
        # TODO: Set error explaining that the ID was not found
        #$self->{_last_error} = ...
        return 0;
    }
}

1;

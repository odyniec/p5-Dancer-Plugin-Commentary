package Dancer::Plugin::Commentary::Storage::Memory;

use strict;
use warnings;

use parent 'Dancer::Plugin::Commentary::Storage';

$Dancer::Plugin::Commentary::Storage::engines{memory} = __PACKAGE__;

sub new {
    my ($class) = @_;

    my $self = {
        _comments =>  [],
    };

    return bless $self, $class;
}

sub init { }

sub add {
    my ($self, $comment) = @_;

    push @{$self->{_comments}}, $comment;

    return $comment;
}

sub get {
    my ($self, $cond) = @_;

    return [ grep {
        eval {
            for my $field (keys %$cond) {
                return 0 if ($_->{$field} ne $cond->{$field});
            }
            return 1;
        }
    } @{$self->{_comments}} ];
}

1;

package Dancer::Plugin::Commentary::Storage::Memory;

use strict;
use warnings;

use parent 'Dancer::Plugin::Commentary::Storage';

my $comments;

sub init {
    $comments = [];
}

sub add {
    my ($comment) = @_;

    push @$comments, $comment;

    return $comment;
}

sub get {
    my ($cond) = @_;

    return [ grep {
        eval {
            for my $field (keys %$cond) {
                return 0 if ($_->{$field} ne $cond->{$field});
            }
            return 1;
        }
    } @$comments ];
}

1;

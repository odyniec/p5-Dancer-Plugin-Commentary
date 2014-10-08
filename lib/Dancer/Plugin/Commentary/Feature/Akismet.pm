package Dancer::Plugin::Commentary::Feature::Akismet;

use strict;
use warnings;

use Net::Akismet;

sub new {
    my ($class, $settings) = @_;

    my $self = {
        _settings => $settings,
    };

    $self->{_akismet} = Net::Akismet->new(
        KEY => $self->{_settings}{api_key},
        URL => $self->{_settings}{url},
    ); # TODO: Handle errors

    return bless $self, $class;
}

1;

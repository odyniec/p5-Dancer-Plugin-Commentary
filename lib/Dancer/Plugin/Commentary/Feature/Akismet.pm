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

sub is_spam {
    my ($self, $args) = @_;

    my $result = $self->{_akismet}->check(
        %{
            map { uc $_ => $args->{$_} }
                grep { exists $args->{$_} }
                    qw( comment_author comment_author_email comment_content
                        comment_user_agent referrer user_ip );
        }
    );

    return { true => 1, false => 0 }->{$result};
}

1;

package Dancer::Plugin::Commentary::Feature::ReCAPTCHA;

use strict;
use warnings;

use Captcha::reCAPTCHA;

sub new {
    my ($class, $settings) = @_;

    my $self = {
        _recaptcha => Captcha::reCAPTCHA->new,
        _settings  => $settings,
    };

    return bless $self, $class;
}

sub check {
    my ($self, $challenge, $response, $ip_address) = @_;

    my $result = $self->{_recaptcha}->check_answer(
        $self->{_settings}{private_key}, $ip_address, $challenge, $response);

    return $result->{is_valid};
}

1;

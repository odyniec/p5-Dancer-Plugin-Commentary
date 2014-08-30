package Dancer::Plugin::Commentary;

use strict;
use warnings;

# ABSTRACT: Add comments to Dancer web apps

# VERSION

use Dancer ':syntax';
use Dancer::Plugin;
use File::ShareDir;
use HTML::Entities;
use URI::Escape;

use Dancer::Plugin::Commentary::Auth::Github;
use Dancer::Plugin::Commentary::Auth::Twitter;

use Dancer::Plugin::Commentary::Storage::Memory;

my $dist_dir = File::ShareDir::dist_dir('Dancer-Plugin-Commentary');
my $assets_dir = path $dist_dir, 'assets';
my $includes_dir = path $dist_dir, 'includes';

my $settings = {
    display_mode    => '',

    %{ plugin_setting() }
};

sub encode_data;
sub js_config;

my @auth_methods = ();

# Initialize the configured authentication methods
while (my ($method, $method_settings) = each %{$settings->{auth}{methods}}) {
    $method = lc $method;
    if (exists $Dancer::Plugin::Commentary::Auth::methods{$method}) {
        push @auth_methods,
            $Dancer::Plugin::Commentary::Auth::methods{$method}->init(
                ref($method_settings) eq 'HASH' ? $method_settings : undef
            );
    }
    else {
        # TODO: No corresponding Auth module found, raise error
    }
}

my $storage = Dancer::Plugin::Commentary::Storage::Memory->new();

hook 'after_file_render' => sub {
    my $response = shift;

    my $content;

    # Ignore non-HTML content
    return unless exists { map { $_ => 1 }
        qw( application/xhtml+xml text/html ) }
        ->{$response->content_type};

    if (ref $response->content) {
        # Seems we're dealing with a filehandle
        local $/ = undef;
        my $fh = $response->content;
        $content = <$fh>;
    }
    else {
        $content = $response->content;
    }

    if ($settings->{display_mode} eq 'iframe' &&
        $ENV{REQUEST_URI} !~ qr{^ /commentary /includes/iframe\.html }x)
    {
        if ($content =~ m{</body>}) {
            # Inject JavaScript code to add an iframe
            my $js = sprintf <<END, request->uri_base, 'commentary', request->uri_base;
<script type="text/javascript">var __commentaryBaseURI = '%s/%s';</script>
<script type="text/javascript" src="%s/commentary/assets/js/commentary-iframe.js"></script>
END
            $content =~ s{</body>}{$js</body>}s;
        }
    }
    else {
        if ($content =~ m{</head>}) {
            if (my $stylesheets = $settings->{stylesheets}) {
                if (ref($stylesheets) eq 'HASH') {
                    # TODO: Handle conditional stylesheets
                }
                else {
                    my $stylesheets_content = join '', map {
                        qq{<link rel="stylesheet" type="text/css" href="$_" />}
                    } @$stylesheets;
                    $content =~ s{</head>}{$stylesheets_content</head>}s;
                }
            }
        }

        if ($content =~ m{</body>}) {
            # Inject our JavaScript code
            my $js = sprintf <<END, to_json(js_config), request->uri_base;
<script type="text/javascript">var __commentaryCfg = %s;</script>
<script type="text/javascript" src="%s/commentary/assets/js/commentary.js"></script>
END
            $content =~ s{</body>}{$js</body>}s;
        }
    }

    $response->content($content);

    return $response;
};

post '/commentary/comments' => sub {
    my $author = {};

    # FIXME: Move method-specific stuff to Auth modules
    if (session('twitter_user')) {
        $author->{auth_method} = 'Twitter';
        $author->{display_name} = session('twitter_user')->{name};
        $author->{url} = session('twitter_user')->{url};
        $author->{avatar_url} = session('twitter_user')->{profile_image_url};
    }
    elsif (session('github_user')) {
        $author->{auth_method} = 'Github';
        $author->{display_name} = session('github_user')->{name};
        $author->{url} = session('github_user')->{html_url};
        $author->{avatar_url} = session('github_user')->{avatar_url};
    }

    my $new_comment = $storage->add({
        timestamp   => time,
        body        => param('body'),
        post_url    => param('post_url'),
        author      => $author,
    });

    return to_json encode_data $new_comment;
};

get '/commentary/comments/**' => sub {
    my ($path) = splat;

    my $post_url = join '/', @$path;

    return to_json encode_data $storage->get({
        post_url => "/$post_url"
    });
};

get '/commentary/comments/' => sub {
    forward '/commentary/comments//';
};

get '/commentary/assets/**' => sub {
    my ($path) = splat;

    return send_file(path($assets_dir, @$path), system_path => 1);
};

get '/commentary/includes/**' => sub {
    my ($path) = splat;

    return send_file(path($includes_dir, @$path), system_path => 1);
};

# Stole^H^H^H^H^HBorrowed (and adapted) from Dancer::Plugin::EscapeHTML
{
    my %seen;

    # Encode values, recursing down into hash/arrayrefs.
    sub encode_data {
        my $in = shift;
     
        return unless defined $in; # avoid interpolation warnings
        return HTML::Entities::encode_entities($in)
            unless ref $in;
     
        return $in
            if exists $seen{scalar $in}; # avoid reference loops
     
        $seen{scalar $in} = 1;
     
        if (ref $in eq 'ARRAY') {
            $in->[$_] = encode_data($in->[$_]) for (0..$#$in);
        } 
        elsif (ref $in eq 'HASH') {
            while (my($k,$v) = each %$in) {
                $in->{$k} = encode_data($v);
            }
        }
     
        return $in;
    }
}

sub js_config {
    my $config = {
        auth => {
            methods => [ ]
        },
        user => {
            auth => 0
        },
        display_mode => $settings->{display_mode},
    };

    my $auth_callback_url;

    if (param('l')) {
        $auth_callback_url = request->uri_base . param('l');
    }
    else {
        $auth_callback_url = request->uri_base . request->uri;
    }

    # FIXME: Scheme sometimes mysteriously disappears from the request object?
    if ($auth_callback_url !~ qr{^ \w+ :// }x) {
        $auth_callback_url =~ s{^ :?/* }{}x;
        $auth_callback_url = (request->scheme || 'http') . '://' . $auth_callback_url;
    }

    for my $method (@auth_methods) {
        my $method_data = $method->method_data($auth_callback_url);

        if (!$config->{user}{auth}) {
            $config->{user}{auth} = $method->auth_data;
            $config->{user} = encode_data {
                %{$config->{user}},
                %{$method_data->{auth_data}}
            };
        }

        push @{$config->{auth}{methods}}, $method_data;
    }

    return $config;
}

1;

__END__

=head1 SYNOPSIS

Add the plugin to your application:

    use Dancer::Plugin::Commentary;

Configure its settings in the YAML configuration file:

    plugins:
      Commentary:
        auth:
          methods:
            twitter:
              consumer_key: "123foo"
              ...
            github:
              client_id: "456bar"
              ...
        display_mode: "iframe"
        storage: "memory"

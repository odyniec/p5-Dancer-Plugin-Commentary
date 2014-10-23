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

use Dancer::Plugin::Commentary::Auth::Facebook;
use Dancer::Plugin::Commentary::Auth::Google;
use Dancer::Plugin::Commentary::Auth::Github;
use Dancer::Plugin::Commentary::Auth::Twitter;

use Dancer::Plugin::Commentary::Storage::DBI;
use Dancer::Plugin::Commentary::Storage::Memory;

my $dist_dir = File::ShareDir::dist_dir('Dancer-Plugin-Commentary');
my $assets_dir = path $dist_dir, 'assets';
my $includes_dir = path $dist_dir, 'includes';

my $settings = {
    display_mode    => '',
    prefix          => '/commentary',
    storage         => 'memory',

    %{ plugin_setting() }
};

sub encode_data;
sub js_config;

my $previous_prefix = prefix;
if ($settings->{prefix}) {
    prefix $settings->{prefix};
}

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

my $storage =
    $Dancer::Plugin::Commentary::Storage::engines{$settings->{storage}}
        ->new($settings->{storage_options} || {});

my $recaptcha;
if (exists $settings->{recaptcha}) {
    use Dancer::Plugin::Commentary::Feature::ReCAPTCHA;
    $recaptcha = Dancer::Plugin::Commentary::Feature::ReCAPTCHA
        ->new($settings->{recaptcha});
}

my $akismet;
if (exists $settings->{akismet}) {
    use Dancer::Plugin::Commentary::Feature::Akismet;
    $akismet = Dancer::Plugin::Commentary::Feature::Akismet->new({
        # TODO: Set URL to root site URL by default?
        # url => ""
        %{$settings->{akismet}},
    });
}

hook 'after_file_render' => \&after_hook;
hook 'after' => \&after_hook;

sub after_hook {
    my $response = shift;
    my $content;

    # Flag the response as already processed to prevent if from being processed
    # twice by both "after_file_render" and "after"
    return if exists $response->{_commentary}{done};
    $response->{_commentary}{done} = 1;

    return unless defined $response->content_type;

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
        request->env->{REQUEST_URI} !~ qr{^ $settings->{prefix} /includes/iframe\.html }x)
    {
        if ($content =~ m{</body>}) {
            # Inject JavaScript code to add an iframe
            my $js = sprintf <<END, (request->uri_base, $settings->{prefix}) x 2;
<script type="text/javascript">var __commentaryBaseURI = '%s%s';</script>
<script type="text/javascript" src="%s%s/assets/js/commentary-iframe.js"></script>
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
            my $js = sprintf <<END, to_json(js_config, {utf8 => 1}), request->uri_base, $settings->{prefix};
<script type="text/javascript">var __commentaryCfg = %s;</script>
<script type="text/javascript" src="%s%s/assets/js/commentary.js"></script>
END
            $content =~ s{</body>}{$js</body>}s;
        }
    }

    $response->content($content);

    return $response;
}

post '/comments' => sub {
    my $comment = from_json(request->body);

    my %user = current_user();  # Comment author information
    my %extra;                  # Extra comment data
    my @errors;

    if (!%user) {
        # Not authenticated
        $user{auth_method} = 'None';

        if (defined $comment->{author}) {
            if ($comment->{author}{name} =~ /\S/) {
                $user{name} = $comment->{author}{name};
            }
            else {
                push @errors, {
                    code => 'params.author.name.empty',
                    msg  => 'Author name cannot be empty',
                };
            }
        }
        else {
            push @errors, {
                code => 'params.author.missing',
                msg  => 'Author information must be provided',
            };
        }
    }

    # Check if comment body is not empty
    if ($comment->{body} =~ /^$/) {
        push @errors, {
            code    => 'params.body.empty',
            msg     => 'Comment body cannot be empty',
        };
    }

    if ($settings->{recaptcha}) {
        if (!$recaptcha->check($comment->{recaptcha_challenge},
            $comment->{recaptcha_response}, request->address))
        {
            push @errors, {
                code => 'recaptcha.invalid',
                msg  => 'Recaptcha response invalid', # FIXME: Nicer wording please
            };
        }
    }

    if (@errors) {
        status 422;
        return to_json \@errors;
    }

    if ($settings->{akismet}) {
        $extra{akismet}->{spam} = $akismet->is_spam({
            comment_author     => $comment->{author}{name},
            # comment_author_email => ,
            comment_content    => $comment->{body},
            comment_user_agent => request->user_agent,
            referrer           => request->referer,
            user_ip            => request->remote_address,
        });
    }

    my $new_comment = $storage->add({
        timestamp   => time,
        body        => $comment->{body},
        post_url    => $comment->{post_url},
        author      => \%user,
        extra       => \%extra,
    });

    status 'created';
    header location => uri_for($settings->{prefix} . '/comments/' .
        $new_comment->{id});
    return to_json encode_data $new_comment;
};

get '/comments/:id' => sub {
    my ($comment) = @{$storage->get({ id => param('id') })};

    if (!$comment) {
        status 'not found';
        return;
    }

    return to_json encode_data $comment;
};

post '/search/comments' => sub {
    my %cond = params('body');

    return to_json encode_data $storage->get({
        map { exists $cond{$_} ? ($_ => $cond{$_}) : () } 
            qw( id post_url )
    });
};

del '/comments/:id' => sub {
    if (!@{$storage->get({ id => param('id') })}) {
        status 'not found';
        return;
    }

    # Check if the current user is the comment author or an admin
    my %user = current_user();

    if (!%user) {
        # Not authorized
        status 'unauthorized';
        return;
    }

    # TODO: Check if the current user is the comment author
    # TODO: If not, check if the current user is an admin

    my $is_author = ($user{auth_method} eq $comment->{author}{auth_method}
        && $user{unique_id} eq $comment->{author}{unique_id});
    my $is_admin = exists $admins{"$user{auth_method}:$user{unique_id}"};
    
    # TODO: Either really remove comment or mark it as removed (based on the
    # configuration)
    if ($storage->remove(param('id'))) {
        status 'no content';
        return;
    }
    else {
        # TODO: Check last_error, there's a chance that the comment happened to
        # get deleted after we checked that it exists (a race condition) -- if
        # that's the case, emit a 404 response.
        status 'internal server error';
        return;
    }
};

get '/assets/**' => sub {
    my ($path) = splat;

    return send_file(path($assets_dir, @$path), system_path => 1);
};

get '/includes/**' => sub {
    my ($path) = splat;

    return send_file(path($includes_dir, @$path), system_path => 1);
};

sub current_user {
    my %user;
    my $method_data = Dancer::Plugin::Commentary::Auth->current_method_data;

    if ($method_data && $method_data->{authenticated}) {
        %user = %{ $method_data->{auth_data} };
        $user{auth_method} = $method_data->{name};
    }

    return %user;
}

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
        prefix => $settings->{prefix},
    };

    my $auth_callback_url;

    if (exists request->params('query')->{l}) {
        $auth_callback_url = request->uri_base . request->params('query')->{'l'};
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
            $config->{user} = encode_data $method_data->{auth_data};
            if ($method_data->{authenticated}) {
                $config->{user}{auth} = { method => $method_data->{name} };
            }
        }

        push @{$config->{auth}{methods}}, $method_data;
    }

    if (exists $settings->{recaptcha}) {
        $config->{recaptcha} = { %{$settings->{recaptcha}} };
        # Do not expose our reCAPTCHA private key
        delete $config->{recaptcha}{private_key};
    }

    return $config;
}

# Set back the previously set prefix
prefix $previous_prefix || undef;

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
        storage_options:
          dsn: "DBI:mysql:database=commentary;host=127.0.0.1;port=3306"   # DBI Data Source Name
          table: "comments"     # Name of the table to store comments
          user: "user"          # Username to connect to the database
          password: "password"  # Password to connect to the database          

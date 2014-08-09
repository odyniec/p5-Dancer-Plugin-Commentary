package Dancer::Plugin::Commentary;

use strict;
use warnings;

# ABSTRACT: Add comments to Dancer web apps

# VERSION

use Dancer ':syntax';
use File::ShareDir;

my $dist_dir = '../Dancer-Plugin-Commentary/share';
# FIXME: File::ShareDir::dist_dir('Dancer-Plugin-Commentary');
my $assets_dir = path $dist_dir, 'assets';

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

    # Inject our JavaScript code
    my $script_tag = '<script type="text/javascript" src="' .
        request->uri_base . '/commentary/assets/js/commentary.js"></script>';
    $content =~ s{</body>}{$script_tag</body>}s;

    $response->content($content);

    return $response;
};

get '/commentary/assets/**' => sub {
    my ($path) = splat;

    return send_file(path($assets_dir, @$path), system_path => 1);
};

1;

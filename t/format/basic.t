use strict;
use warnings;

use Test::More;

use_ok 'Dancer::Plugin::Commentary::Format::Basic';

my $text_urls = <<END;
Perl:
http://perl.org/
Perl Dancer:
http://perldancer.org/
URL with HTTPS and fragment:
https://url.with/#fragment
END
my $html_urls = <<END;
Perl:
<a href="http://perl.org/">http://perl.org/</a>
Perl Dancer:
<a href="http://perldancer.org/">http://perldancer.org/</a>
URL with HTTPS and fragment:
<a href="https://url.with/#fragment">https://url.with/#fragment</a>
END

is Dancer::Plugin::Commentary::Format::Basic::to_html($text_urls),
    $html_urls, 'URLs get converted as expected';

my $text_paragraphs = q{
First paragraph.

Second paragraph.

Third paragraph.
};
my $html_paragraphs = '<p>First paragraph.</p>' .
    "<p>Second paragraph.</p><p>Third paragraph.</p>";

is Dancer::Plugin::Commentary::Format::Basic::to_html($text_paragraphs),
    $html_paragraphs, 'Paragraphs are created as expected';

done_testing;

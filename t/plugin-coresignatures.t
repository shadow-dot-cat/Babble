use strictures 2;
use Test::More;
use Babble::Plugin::CoreSignatures;
use Babble::Match;

my $code = <<'END';
  sub left :Attr ($sig) { }
  sub right ($sig) :Attr { }
END

my $cs = Babble::Plugin::CoreSignatures->new;

foreach my $type (qw(plain)) {
  my $top = Babble::Match->new(top_rule => 'Document', text => $code);
  $cs->${\"transform_to_${type}"}($top);
  warn $top->text;
}

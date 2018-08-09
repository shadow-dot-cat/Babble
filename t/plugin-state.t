use strictures 2;
use Test::More;
use Babble::Plugin::State;
use Babble::Match;

my $st = Babble::Plugin::State->new;

my @cand = (
  [ 'my $foo = sub { my ($x) = @_; state $y; return 3; };',
    'my $foo = do { my $y; sub { my ($x) = @_; do { no warnings qw(void); $y }; return 3; } };' ],
);

foreach my $cand (@cand) {
  my ($from, $to) = @$cand;
  my $top = Babble::Match->new(top_rule => 'Document', text => $from);
  $st->transform_to_plain($top);
  is($top->text, $to, "${from}");
}

done_testing;

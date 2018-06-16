use Test::More;
use Babble::Match;

my $test = Babble::Match->new(
  top_rule => '(?&PerlDocument)',
  text => q{
    sub foo {
    }
    sub bar {
    }
  },
);

ok($test->is_valid);

use Devel::Dwarn; Dwarn($test->match_positions_of('SubroutineDeclaration'));

done_testing;

use strict;
use warnings;
use Test::More;
use Babble::Match;

my $test = Babble::Match->new(
  top_rule => '(?&PerlDocument)',
  text => q{
    my $x = 1;
    sub foo {
      "foo"
    }
    warn "yay";
    sub bar {
      "bar"
    }
  },
);

ok($test->is_valid, 'Initial object valid');

my $old_text = $test->text;

$test->each_match_of('SubroutineDeclaration' => sub {
  my ($match) = @_;
  my $text = $match->text;
  my ($name) = $text =~ /\Asub (\w+)/;
  $text =~ s/{/{ # define $name/;
  $match->replace_text($text);
});

(my $new_text = $old_text) =~ s/sub (\w+) {/sub $1 { # define $1/g;

is($test->text, $new_text, 'Transform happened as expected');

ok($test->is_valid, 'Still valid');

done_testing;

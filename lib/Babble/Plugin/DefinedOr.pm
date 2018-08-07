package Babble::Plugin::DefinedOr;

use Moo;

sub transform_to_plain {
  my ($self, $top) = @_;
  $top->each_match_within(BinaryExpression => [
     [ before => '(?>(?&PerlPrefixPostfixTerm))' ],
     '(?>(?&PerlOWS) //)', '(?>(?&PerlOWS))',
     [ after => '(?>(?&PerlPrefixPostfixTerm))' ],
  ] => sub {
    my ($m) = @_;
    my ($before, $after) = map $_->text, @{$m->submatches}{qw(before after)};
    s/^\s+//, s/\s+$// for ($before, $after);
    $m->replace_text('(map +(defined($_) ? $_ : '.$after.'), '.$before.')[0]');
  });
}

1;

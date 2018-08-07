package Babble::Plugin::DefinedOr;

use Moo;

sub transform_to_plain {
  my ($self, $top) = @_;
  my $tf = sub {
    my ($m) = @_;
    my ($before, $after) = map $_->text, @{$m->submatches}{qw(before after)};
    s/^\s+//, s/\s+$// for ($before, $after);
    if ($m->submatches->{op}->text =~ /=$/) {
      $after = '$_ = '.$after;
    }
    $m->replace_text('(map +(defined($_) ? $_ : '.$after.'), '.$before.')[0]');
  };
  $top->each_match_within(BinaryExpression => [
     [ before => '(?>(?&PerlPrefixPostfixTerm))' ],
     [ op => '(?>(?&PerlOWS) //)' ], '(?>(?&PerlOWS))',
     [ after => '(?>(?&PerlPrefixPostfixTerm))' ],
  ] => $tf);
  $top->each_match_within(Assignment => [
     [ before => '(?>(?&PerlPrefixPostfixTerm))' ],
     [ op => '(?>(?&PerlOWS) //=)' ], '(?>(?&PerlOWS))',
     [ after => '(?>(?&PerlPrefixPostfixTerm))' ],
  ] => $tf);
}

1;

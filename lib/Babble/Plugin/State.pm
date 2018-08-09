package Babble::Plugin::State;

use Moo;

sub transform_to_plain {
  my ($self, $top) = @_;
  $top->each_match_of(AnonymousSubroutine => sub {
    my ($m) = @_;
    my @states;
    $m->each_match_within(Assignment => [
      'state \b (?>(?&PerlOWS))',
      [ type => '(?: (?&PerlQualifiedIdentifier) (?&PerlOWS) )?+' ],
      [ declares => '(?>(?&PerlLvalue))' ],
      '(?>(?&PerlOWS))',
      [ attributes => '(?&PerlAttributes)?+' ],
      '(?: (?>(?&PerlOWS)) = (?>&PerlOWS)',
        [ assigns => '(?&PerlConditionalExpression)' ],
      ')*+',
    ] => sub {
      my ($m) = @_;
      my $st = $m->subtexts;
      push @states, $st;
      $m->replace_text('do { no warnings qw(void); '.$st->{declares}.' }');
    });
    if (@states) {
      my $state_statements = join ' ',
         map {
           'my '.$_->{type}.$_->{declares}
           .($_->{attributes} ? ' '.$_->{attributes} : '')
           .';'
         } @states;
      $m->transform_text(sub {
        s/\A/do { ${state_statements} /;
        s/\Z/ }/;
      });
    }
  });
}

1;

__END__


    (?<PerlVariableDeclaration>   (?<PerlStdVariableDeclaration>
        (?> my | state | our ) \b           (?>(?&PerlOWS))
        (?: (?&PerlQualifiedIdentifier)        (?&PerlOWS)  )?+
        (?>(?&PerlLvalue))                  (?>(?&PerlOWS))
        (?&PerlAttributes)?+
    )) # End of rule

package Babble::Plugin::CoreSignatures;

use Moo;

sub extend_grammar { } # PPR::X can already parse everything we need

# .......bbbbbSSSSSSSa
# sub foo :Bar ($baz) {

# .......bSSSSSSSaaaaa
# sub foo ($baz) :Bar {

sub transform_to_signatures {
  my ($self, $top) = @_;
  my $tf = sub {
    my $s = (my $m = shift)->submatches;
    if ((my $after = $s->{after}->text) =~ /\S/) {
      $s->{after}->replace_text('');
      $s->{before}->replace_text($s->{before}->text.$after);
    }
  };
  $self->_transform_signatures($top, $tf);
}

sub transform_to_oldsignatures {
  my ($self, $top) = @_;
  my $tf = sub {
    my $s = (my $m = shift)->submatches;
    if ((my $before = $s->{before}->text) =~ /\S/) {
      $s->{before}->replace_text('');
      $s->{after}->replace_text($before.$s->{after}->text);
    }
  };
  $self->_transform_signatures($top, $tf);
}

sub transform_to_plain {
  my ($self, $top) = @_;
  my $tf = sub {
    my $s = (my $m = shift)->submatches;
    my $proto = '';
    my $grammar = $m->grammar_regexp;
    foreach my $try (@{$s}{qw(before after)}) {
      local $try->{grammar_regexp} = qr{
        (?(DEFINE)
          (?<PerlAttributes>(?<PerlStdAttributes>
            (?=:)(?&PerlAttribute)
            (?&PerlAttribute)*
          ))
          (?<PerlAttribute>(?<PerlStdAttribute>
            (?&PerlOWS) :? (?&PerlOWS)
            (?&PerlIdentifier)
            (?: (?= \( ) (?&PPR_X_quotelike_body) )?
          ))
        )
        ${grammar}
      }x;
      my $each; $each = sub {
        my ($attr) = @_;
        if ($attr->text =~ /prototype(\(.*?\))/) {
          $proto = $1;
          $attr->replace_text('');
          $each = sub {
            my ($attr) = @_;
            $attr->replace_text(s/^(\s*)/$1:/) unless $attr->text =~ /^\s*:/;
            $each = sub {};
          };
        }
      };
      $try->each_match_of(Attribute => sub { $each->(@_) });
      undef($each);
    }

    s/\A\s*\(//, s/\)\s*\Z// for my $sig_orig = $s->{sig}->text;
    my @sig_parts = grep defined($_),
                      $sig_orig =~ /((?>(?&PerlExpression))) ${grammar}/xg;

    my (@sig_text, @defaults);

    foreach my $idx (0..$#sig_parts) {
      my $part = $sig_parts[$idx];
      if ($part =~ s/^(\S+?)\s*=\s*(.*?)(,$|$)/$1$3/) {
        push @defaults, "$1 = $2 if \@_ <= $idx";
      }
      push @sig_text, $part;
    }

    my $sig_text = join ' ', @sig_text;
    $s->{body}->transform_text(sub { s/^{/{ my (${sig_text}) = \@_; / });
    if ($proto) {
      $s->{sig}->transform_text(sub {
        s/\A(\s*)\(.*\)(\s*)\Z/${1}${proto}${2}/;
      });
    } else {
      $s->{sig}->replace_text('');
    }
  };
  $self->_transform_signatures($top, $tf);
}

sub _transform_signatures {
  my ($self, $top, $tf) = @_;
  my @common = (
    '(?:', # 5.20, 5.28+
      [ before => '(?: (?&PerlOWS) (?>(?&PerlAttributes)) )?+' ],
      [ sig => '(?&PerlOWS) (?&PerlParenthesesList)' ], # not optional for us
      [ after => '(?&PerlOWS)' ],
    '|', # 5.22 - 5.26
      [ before => '(?&PerlOWS)' ],
      [ sig => '(?&PerlParenthesesList) (?&PerlOWS)' ], # not optional for us
      [ after => '(?: (?>(?&PerlAttributes)) (?&PerlOWS) )?+' ],
    ')',
    [ body => '(?&PerlBlock)' ],
  );
  $top->each_match_within('SubroutineDeclaration' => [
    'sub \b (?&PerlOWS) (?&PerlOldQualifiedIdentifier)',
    @common,
  ], $tf);
  $top->each_match_within('AnonymousSubroutine' => [
    'sub \b',
    @common,
  ], $tf);
}

1;

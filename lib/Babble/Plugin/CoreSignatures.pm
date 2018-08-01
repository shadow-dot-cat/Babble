package Babble::Plugin::CoreSignatures;

use strictures 2;
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
  $top->each_match_within(
    UseStatement =>
    [ 'use\s+experimental\s+', [ explist => '.*?' ], ';' ],
    sub {
      my ($m) = @_;
      my $explist = $m->submatches->{explist};
      return unless my @explist_names = eval $explist->text;
      my @remain = grep $_ ne 'signatures', @explist_names;
      return unless @remain < @explist_names;
      unless (@remain) {
        $m->replace_text('');
        return;
      }
      $explist->replace_text('qw('.join(' ', @remain).')');
    }
  );
  my $tf = sub {
    my $s = (my $m = shift)->submatches;

    # shift attributes after first before we go hunting for :prototype
    if ((my $before = $s->{before}->text) =~ /\S/) {
      $s->{before}->replace_text('');
      $s->{after}->replace_text($before.$s->{after}->text);
    }

    my $proto = '';
    my $grammar = $m->grammar_regexp;
    {
      my $try = $s->{after};
      local $try->{top_rule} = 'Attributes';
      local $try->{grammar_regexp} = qr{
        (?(DEFINE)
          (?<PerlAttributes>(?<PerlStdAttributes>
            (?=(?&PerlOWS):)(?&PerlAttribute)
            (?&PerlAttribute)*
          ))
          (?<PerlAttribute>(?<PerlStdAttribute>
            (?&PerlOWS) :? (?&PerlOWS)
            (?&PerlIdentifier)
            (?: (?= \( ) (?&PPR_X_quotelike_body) )?+
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
            $attr->transform_text(sub { s/^(\s*)/${1}:/ }) unless $attr->text =~ /^\s*:/;
            $each = sub {};
          };
        }
      };
      $try->each_match_of(Attribute => sub { $each->(@_) });
      undef($each);
    }

    s/\A\s*\(//, s/\)\s*\Z// for my $sig_orig = $s->{sig}->text;
    my @sig_parts = grep defined($_),
                      $sig_orig =~ /((?&PerlAssignment)) ${grammar}/xg;

    my (@sig_text, @defaults);

    foreach my $idx (0..$#sig_parts) {
      my $part = $sig_parts[$idx];
      if ($part =~ s/^(\S+?)\s*=\s*(.*?)(,$|$)/$1$3/) {
        push @defaults, "$1 = $2 if \@_ <= $idx;";
      }
      push @sig_text, $part;
    }

    my $sig_text = 'my ('.(join ', ', @sig_text).') = @_;';
    my $code = join ' ', $sig_text, @defaults;
    $s->{body}->transform_text(sub { s/^{/{ ${code}/ });
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

package Babble::Match;

use PPR::X;
use Mu;
use re 'eval';

ro 'top_rule';
rwp 'text';
lazy 'grammar_regexp' => sub { $PPR::X::GRAMMAR };

lazy top_re => sub {
  my ($self) = @_;
  my $top = $self->_rule_to_re($self->top_rule);
  return "\\A${top}\\Z";
};

lazy submatches => sub {
  my ($self) = @_;
  return {} unless ref(my $top = $self->top_rule);
  my (%subrules, @names);
  my $re = join '', map {
    ref($_)
      ? do {
          my ($name, $rule) = @$_;
          push @names, $name;
          $subrules{$name} = $rule;
          "(${rule})"
        }
      : $_
  } @$top;
  return {} unless @names;
  my @values = $self->text =~ /\A${re}\Z ${\$self->grammar_regexp}/x;
  die "Match failed" unless @values;
  my %submatches;
  require Babble::SubMatch;
  foreach my $idx (0 .. $#names) {
    $submatches{$names[$idx]} = Babble::SubMatch->new(
      top_rule => $subrules{$names[$idx]},
      start => $-[$idx+1],
      text => $values[$idx],
      parent => $self,
    );
  }
  return \%submatches;
};

sub _rule_to_re {
  my $re = $_[1];
  return $re unless ref($re);
  return join '', map +(ref($_) ? $_->[1] : $_), @$re;
}

sub is_valid {
  my ($self) = @_;
  return !!$self->text =~ /${\$self->top_re} ${\$self->grammar_regexp}/x;
}

sub match_positions_of {
  my ($self, $of) = @_;
  our @F;
  my $wrapped = qr{(?(DEFINE)
    (?<Perl${of}>((?&PerlStd${of}))(?{ push @F, [ pos() - length($^N), length($^N) ] }))
  ) ${\$self->grammar_regexp}}x;
  my @found = do {
    local @F;
    local $_ = $self->text;
    /${\$self->top_re} ${wrapped}/x;
    @F;
  };
  return @found;
}

sub each_match_of {
  my ($self, $of, $call) = @_;
  my @found = $self->match_positions_of($of);
  return unless @found;
  require Babble::SubMatch;
  while (my $f = shift @found) {
    my $match = substr($self->text, $f->[0], $f->[1]);
    my $obj = Babble::SubMatch->new(
                top_rule => "(?&Perl${of})",
                start => $f->[0],
                text => $match,
                parent => $self,
              );
    $call->($obj);
    if (my $len_diff = length($obj->text) - $f->[1]) {
      foreach my $later (@found) {
        if ($later->[0] <= $f->[0]) {
          $later->[1] += $len_diff;
        } else {
          $later->[0] += $len_diff;
        }
      }
    }
  }
  return $self;
}

sub each_match_within {
  my ($self, $within, $rule, $call) = @_;
  my $match_re = $self->_rule_to_re($rule);
  my $extend_grammar = qq{
    (?(DEFINE)
      (?<PerlBabbleInnerMatch>(?<PerlStdBabbleInnerMatch> ${match_re}))
      (?<Perl${within}> (?&PerlBabbleInnerMatch) | (?&PerlStd${within}))
    )
  };
  local $self->{grammar_regexp} = join "\n", $extend_grammar, $self->grammar_regexp;
  $self->each_match_of(BabbleInnerMatch => sub {
    $_[0]->{top_rule} = $rule; # intentionally hacky, should go away (or rwp) later
    $call->($_[0]);
  });
  return $self;
}

sub replace_substring {
  my ($self, $start, $length, $replace) = @_;
  my $text = $self->text;
  substr($text, $start, $length, $replace);
  $self->_set_text($text);
  foreach my $submatch (values %{$self->submatches}) {
    if ($submatch->start > $start) {
      $submatch->{start} += length($replace) - $length;
    }
  }
  return $self;
}

1;

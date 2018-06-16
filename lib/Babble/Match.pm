package Babble::Match;

use PPR::X;
use Mu;
use re 'eval';

ro 'top_rule';
rwp 'text';
lazy 'grammar_regexp' => sub { $PPR::X::GRAMMAR };

sub is_valid {
  my ($self) = @_;
  return !!$self->text =~ /^${\$self->top_rule}$ ${\$self->grammar_regexp}/x;
}

sub match_positions_of {
  my ($self, $of) = @_;
  my $name = "Perl${of}";
  my $std_name = "PerlStd${of}";
  our @F;
  my $wrapped = qr{(?(DEFINE)
    (?<${name}>((?&${std_name}))(?{ push @F, [ pos() - length($^N), pos() ] }))
  ) ${\$self->grammar_regexp}}x;
  my @found = do {
    local @F;
    local $_ = $self->text;
    /\A${\$self->top_rule}\Z ${wrapped}/x;
    @F;
  };
  return \@found;
}

1;

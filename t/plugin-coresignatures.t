use strictures 2;
use Test::More;
use Babble::Plugin::CoreSignatures;
use Babble::Match;

my $code = <<'END';
  sub left :Attr ($sig, $extra = 2) {
    my $anon_right = sub ($sig) :Attr { }
  }
  sub right ($sig) :Attr :prototype($) {
    my $anon_left = sub :Attr ($sig) { }
  }
END

my %expect = (
  signatures => <<'END',
  sub left :Attr ($sig, $extra = 2) {
    my $anon_right = sub :Attr ($sig) { }
  }
  sub right :Attr :prototype($) ($sig) {
    my $anon_left = sub :Attr ($sig) { }
  }
END
  oldsignatures => <<'END',
  sub left ($sig, $extra = 2) :Attr {
    my $anon_right = sub ($sig) :Attr { }
  }
  sub right ($sig) :Attr :prototype($) {
    my $anon_left = sub ($sig) :Attr { }
  }
END
  plain => <<'END',
  sub left :Attr { my ($sig, $extra) = @_; $extra = 2 if @_ <= 1;
    my $anon_right = sub :Attr { my ($sig) = @_; }
  }
  sub right ($) :Attr { my ($sig) = @_;
    my $anon_left = sub :Attr { my ($sig) = @_; }
  }
END
);


my $cs = Babble::Plugin::CoreSignatures->new;

foreach my $type (qw(signatures oldsignatures plain)) {
  my $top = Babble::Match->new(top_rule => 'Document', text => $code);
  $cs->${\"transform_to_${type}"}($top);
  is($top->text, $expect{$type}, "Rendered ${type} correctly");
}

done_testing;

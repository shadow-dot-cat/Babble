use strictures 2;
use Test::More;
use Babble::Plugin::PostfixDeref;
use Babble::Match;

my $pd = Babble::Plugin::PostfixDeref->new;

my @cand = (
  [ 'my $x = $foo->$*; my @y = $bar->baz->@*;',
    'my $x = (map $$_, $foo)[0]; my @y = (map @{$_}, $bar->baz);' ],
  [ 'my $x = ($foo->bar->$*)->baz->@*;',
    'my $x = (map @{$_}, ((map $$_, $foo->bar)[0])->baz);' ],
  [ 'my @val = $foo->@{qw(key names)};',
    'my @val = (map @{$_}{qw(key names)}, $foo);' ],
  [ 'my $val = $foo[0];',
    'my $val = $foo[0];' ],
  [ 'my $val = $foo[$idx];',
    'my $val = $foo[$idx];' ],
  [ '$bar->{key0}{key1}',
    '$bar->{key0}{key1}' ],
  [ '$bar->{key0}{key1}->@*',
    '(map @{$_}, $bar->{key0}{key1})' ],
  [ '$bar->{key0}{key1}->@[@idx]',
    '(map @{$_}[@idx], $bar->{key0}{key1})' ],
  [ 'my %val = $foo->%[@idx];',
    'my %val = (map %{$_}[@idx], $foo);' ],
  [ 'my %val = $foo->%{qw(key names)};',
    'my %val = (map %{$_}{qw(key names)}, $foo);' ],
  [ 'qq{ $foo->@* }',
    'qq{ @{[ (map @{$_}, $foo) ]} }' ],
  [ 'qq{ $foo->@{qw(key names)} }',
    'qq{ @{[ (map @{$_}{qw(key names)}, $foo) ]} }' ],

  [ 'qq{ $foo }',
    'qq{ $foo }' ],
  [ 'qq{ $foo $bar }',
    'qq{ $foo $bar }' ],

  [ 'qq{ $foo->%* }',
    'qq{ $foo->%* }' ],
  [ 'qq{ $foo->%* $bar->@* }',
    'qq{ $foo->%* @{[ (map @{$_}, $bar) ]} }' ],

  [ 'qq{ $foo->$* }',
    'qq{ @{[ (map $$_, $foo)[0] ]} }' ],

  [ '$foo->$#*',
    '(map $#$_, $foo)[0]' ],
  [ 'qq{ $foo->$#* }',
    'qq{ @{[ (map $#$_, $foo)[0] ]} }' ],
);

foreach my $cand (@cand) {
  my ($from, $to) = @$cand;
  my $top = Babble::Match->new(top_rule => 'Document', text => $from);
  $pd->transform_to_plain($top);
  is($top->text, $to, "${from}");
}

done_testing;

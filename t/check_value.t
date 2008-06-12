#!/usr/bin/perl -w

require 5.001;

$runtests=shift(@ARGV);
if ( -f "t/test.pl" ) {
  require "t/test.pl";
  $dir="t";
} elsif ( -f "test.pl" ) {
  require "test.pl";
  $dir=".";
} else {
  die "ERROR: cannot find test.pl\n";
}

unshift(@INC,$dir);
use Data::NDS;

sub test {
  (@test)=@_;
  my $obj = pop(@test);
  return $obj->check_value(@test);
}

$obj = new Data::NDS;

$o = { a => [ 1,2,3 ],
       b => { bb => 1 },
     };
$obj->check_structure($o,1);

$s  = "foo";
$l  = [ 4,5,6 ];
$hs = { bb => 2 };
$hl = { bb => [1] };

$tests = 
[
  [ [ "/a", $s ],
    [ 2, "/a" ] ],

  [ [ "/a", $l ],
    [ 0, "" ] ],

  [ [ "/b", $s ],
    [ 2, "/b" ] ],

  [ [ "/b", $hs ],
    [ 0, "" ] ],

  [ [ "/b", $hl ],
    [ 2, "/b/bb" ] ],
];

print "check_value...\n";
test_Func(\&test,$tests,$runtests,$obj);

1;
# Local Variables:
# mode: cperl
# indent-tabs-mode: nil
# cperl-indent-level: 3
# cperl-continued-statement-offset: 2
# cperl-continued-brace-offset: 0
# cperl-brace-offset: 0
# cperl-brace-imaginary-offset: 0
# cperl-label-offset: -2
# End:


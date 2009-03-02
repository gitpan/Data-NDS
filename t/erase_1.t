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

  my @out  = $obj->keys(@test);
  push(@out,"--");
  $obj->erase(@test);
  push(@out,$obj->err());
  push(@out,$obj->keys(@test));
  return @out;
}

$obj = new Data::NDS;

$nds1= { "a" => 1,
         "b" => 2 };
$nds2= { "a" => 1,
         "b" => 2 };
$obj->nds("ele1",$nds1,1);
$obj->nds("ele2",$nds2,1);

$tests = "
ele1 ~ a b -- _blank_

ele2 / ~ a b -- _blank_

";

print "erase (entire hash)...\n";
test_Func(\&test,$tests,$runtests);

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


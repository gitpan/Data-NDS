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

  my @out  = $obj->keys(@test);
  push(@out,"--");
  push(@out,$obj->erase(@test));
  push(@out,"--");
  push(@out,$obj->keys(@test));
  return @out;
}

$obj = new Data::NDS;

$nds = [ "a", "b" ];
$obj->nds("ele1",$nds,1);
$obj->nds("ele2",$nds,1);

$tests = "
ele1 ~ 0 1 -- 0 --

ele2 / ~ 0 1 -- 0 --

";

print "erase (entire list)...\n";
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


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
  if ($test[0] eq "CHECK") {
    return @test[1..$#test];
  }
  return $obj->get_structure(@test);
}

$obj = new Data::NDS;

$o = { a => [ 1,2,3 ],
       b => { bb => 1 },
     };
($e1,$p1) = $obj->check_structure($o,1);

$o = { a => [ 1 ] };
($e2,$p2) = $obj->check_structure($o,1);

$o = { a => [ { aa => 1 } ] };
($e3,$p3) = $obj->check_structure($o,1);

$o = { a => 1 };
($e4,$p4) = $obj->check_structure($o,1);

$o = { b => { bb => [ 1 ] } };
($e5,$p5) = $obj->check_structure($o,1);

$o = { c => 1 };
($e6,$p6) = $obj->check_structure($o,0);

$o = { b => { cc => [ 1 ] } };
($e7,$p7) = $obj->check_structure($o,1);

$tests = "

CHECK $e1 $p1 ~ 0

CHECK $e2 $p2 ~ 0

CHECK $e3 $p3 ~ 2 /a/*

CHECK $e4 $p4 ~ 2 /a

CHECK $e5 $p5 ~ 2 /b/bb

CHECK $e6 $p6 ~ 1 /c

CHECK $e7 $p7 ~ 0

/a ~ array

/b ~ hash

/b/bb ~ scalar

/b/cc ~ array

";

print "check_structure...\n";
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


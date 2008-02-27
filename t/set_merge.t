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
  return $obj->set_merge(@test);
}

$obj = new Data::NDS;

$obj->set_structure("type","hash","/h");

$obj->set_structure("type","scalar","/s");

$obj->set_structure("type","array","/ol");
$obj->set_structure("ordered",1,"/ol");

$obj->set_structure("type","array","/ul");
$obj->set_structure("ordered",0,"/ul");

$tests = "

merge_hash keep ~ 0

merge_hash append ~ 100

merge_ol keep ~ 0

merge_ol append ~ 101

merge_ul keep ~ 0

merge_ul append ~ 0

merge_ul merge ~ 102

merge_scalar keep ~ 0

merge_scalar merge ~ 103

merge /u append ~ 121

merge /h foo ~ 132

merge /h merge ~ 0

merge /h keep ~ 120

merge /s foo ~ 133

merge /s replace ~ 0

merge /ol foo ~ 130

merge /ol append ~ 130

merge /ol merge ~ 0

merge /ul foo ~ 131

merge /ul merge ~ 131

merge /ul append ~ 0

";

print "set_merge...\n";
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


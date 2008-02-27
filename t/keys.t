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
  my $nds = pop(@test);
  my $obj = pop(@test);
  return $obj->keys($nds,@test);
}

$obj = new Data::NDS;
$nds = { "b" => "foo",
         "c" => [ "c1", "c2" ],
         "d" => { "d1k" => "d1v", "d2k" => "d2v" },
       };

$tests = "

/b ~

/c ~ 0 1

/d ~ d1k d2k

";

print "keys...\n";
test_Func(\&test,$tests,$runtests,$obj,$nds);

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


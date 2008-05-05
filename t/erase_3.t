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
  my($ele,$delpath,$keyspath,$vals,$obj) = @test;

  my @out  = $obj->keys($ele,$keyspath);
  push(@out,"--");
  push(@out,$obj->erase($ele,$delpath));
  push(@out,"--");
  push(@out,$obj->keys($ele,$keyspath));
  push(@out,$obj->values($ele,$keyspath))  if ($vals);
  return @out;
}

$obj = new Data::NDS;

$obj->set_structure("type","array","/c");
$obj->set_structure("ordered","0","/c");
$obj->set_structure("type","array","/d");
$obj->set_structure("ordered","1","/d");

$nds = { "a" => 1,
         "b" => { "x" => 11, "y" => 22 },
         "c" => [ qw(alpha beta gamma delta) ],
         "d" => [ qw(alpha beta gamma delta) ],
       };
$obj->nds("ele",$nds,1);

$tests =
[
  [
    [ qw(ele /a / 0) ],
    [ qw(a b c d -- 0 -- b c d) ]
  ],

  [
    [ qw(ele /b/x /b 1) ],
    [ qw(x y -- 0 -- y 22) ]
  ],

  [
    [ qw(ele /c/1 /c 1) ],
    [ qw(0 1 2 3 -- 0 -- 0 1 2 alpha gamma delta) ]
  ],

  [
    [ qw(ele /d/1 /d 1) ],
    [ qw(0 1 2 3 -- 0 -- 0 2 3 alpha gamma delta) ]
  ],

];

print "erase...\n";
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


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

  my $i = $obj->identical("nds1","nds2",@test);
  my $c = $obj->contains("nds1","nds2",@test);
  return($i,$c);
}

$obj = new Data::NDS;

$obj->set_structure("type",    "array",   "/ele04");
$obj->set_structure("ordered", "0",       "/ele04");
$obj->set_structure("type",    "array",   "/ele04/*");
$obj->set_structure("ordered", "0",       "/ele04/*");


$nds1 = { 
  "ele01" => { "a"  => "foo",
               "b"  => "bar" },
  "ele02" => { "a"  => "foo",
               "b"  => "bar" },
  "ele03" => { "a"  => "foo",
               "b"  => "bar" },
  "ele04" => [ [ qw(l1a l1b l1c) ],
               [ qw(l2a l2b l2c) ] ],
};

$nds2 = { 
  "ele01" => { "a"  => "foo",
               "b"  => "bar",
               "c"  => "baz" },
  "ele02" => { "a"  => "foo",
               "c"  => "baz" },
  "ele03" => { "a"  => "foo",
               "b"  => "baz" },
  "ele04" => [ [ qw(l1a l1c l1b) ],
               [ qw(l2a l2c l2b) ] ],
};

$obj->nds("nds1",$nds1,1);
$obj->nds("nds2",$nds2,1);

$tests = "
/ele01 ~ 0 0

/ele02 ~ 0 0

/ele03 ~ 0 0

";
# /ele04 ~ 0 0

print "identical/contains...\n";
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


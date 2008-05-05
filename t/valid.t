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
  return $obj->valid($nds,@test);
}

$obj = new Data::NDS;
$nds = { "a" => undef,
         "b" => "foo",
         "c" => [ "c1", "c2" ],
         "d" => { "d1k" => "d1v", "d2k" => "d2v" },
         "e" => \&foo
       };

$tests = "
/a ~ 1 _undef_

/a/b ~ 0 0 /a/b

/x ~ 0 1 /x

/d/d3k ~ 0 1 /d/d3k

/c/2 ~ 0 2 /c/2

/b/x ~ 0 10 /b/x

/e/x ~ 0 11 /e/x

/c/x ~ 0 12 /c/x

/b ~ 1 foo

/c/1 ~ 1 c2

/d/d2k ~ 1 d2v

/f/1/2 ~ 0 1 /f

";

print "valid...\n";
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


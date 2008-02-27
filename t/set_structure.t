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
  return $obj->set_structure(@test);
}

$obj = new Data::NDS;

$$obj{"struct"} = { "/z"  => { "type"    => "array/hash",
                             },
                  };

$tests = "

type hash / ~ 0

type foo /a ~ 1

type hash /a ~ 0

type scalar /a ~ 2

type scalar /z ~ 3

type array /z ~ 0

foo keep ~ 10

foo x /a ~ 11

type array /b ~ 0

ordered x /b ~ 100

ordered 1 /a ~ 101

ordered 1 /b ~ 0

ordered 0 /b ~ 102

type array /c ~ 0

uniform 0 /c ~ 0

ordered 0 /c ~ 102

type array /d ~ 0

uniform x /d ~ 110

type scalar f ~ 0

uniform 1 /f ~ 111

uniform 1 /d ~ 0

uniform 0 /d ~ 112

type array /e ~ 0

ordered 0 /e ~ 0

uniform 0 /e ~ 112

type scalar /k ~ 0

type hash /k/l/m ~ 130

type array /g ~ 0

uniform 1 /g ~ 0

type array /g/1 ~ 140

type array /g/* ~ 0

type array /h ~ 0

uniform 0 /h ~ 0

type array /h/1 ~ 0

type array /h/* ~ 141

type array /h/foo ~ 150

type hash /i ~ 0

uniform 1 /i ~ 0

type array /i/x ~ 160

type array /i/* ~ 0

type hash /j ~ 0

uniform 0 /j ~ 0

type array /j/x ~ 0

type array /j/* ~ 161

ordered 2 ~ 170

uniform_hash 2 ~ 180

uniform_ol 2 ~ 181

";

print "set_structure...\n";
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


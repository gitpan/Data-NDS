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
  return $obj->get_structure(@test);
}

$obj = new Data::NDS;
$$obj{"struct"} = { "/"    => { "type"    => "hash",
                              },
                    "/hn"  => { "type"    => "hash",
                                "uniform" => 0,
                              },
                    "/hu"  => { "type"    => "hash",
                                "uniform" => 1,
                              },
                    "/auu" => { "type"    => "array",
                                "ordered" => 0,
                                "uniform" => 1,
                              },
                    "/aou" => { "type"    => "array",
                                "ordered" => 1,
                                "uniform" => 1,
                              },
                    "/aon" => { "type"    => "array",
                                "ordered" => 1,
                                "uniform" => 0,
                              },
                    "/s" =>   { "type"    => "scalar",
                              },

                    "/auu/*" => { "type"    => "scalar" },
                    "/aou/*" => { "type"    => "other" },
                    "/aon/0" => { "type"    => "scalar" },
                    "/aon/1" => { "type"    => "other" },

                    "/hn/a"  => { "type"    => "scalar" },
                    "/hn/b"  => { "type"    => "other" },
                    "/hu/*"  => { "type"    => "scalar" },

                    "/h"     => { "type"    => "hash" },
                    "/a"     => { "type"    => "array" },

                    "/h2"     => { "type"    => "hash",
                                   "uniform" => 1 },
                    "/h2/*"   => { "type"    => "hash",
                                   "uniform" => 1 },
                    "/h2/*/*" => { "type"    => "hash",
                                   "uniform" => 1 },

                  };

$tests = "

/z ~

/z type ~

/hn type ~ hash

/hn ~ hash

/auu/1 ~ scalar

/auu/* ~ scalar

/aou/1 ~ other

/aou/* ~ other

/aon/0 ~ scalar

/aon/1 ~ other

/aon/2 ~

/aon/* ~

/hn/a ~ scalar

/hn/b ~ other

/hn/c ~

/hn/* ~

/hu/a ~ scalar

/hu/* ~ scalar

/auu ordered ~ 0

/aon ordered ~ 1

/auu uniform ~ 1

/aon uniform ~ 0

/hn ordered ~

/hn uniform ~ 0

/hu uniform ~ 1

/a uniform ~ 1

/a ordered ~ 0

/h2/*/foo type ~ hash

/h2/a/foo type ~ hash

";

print "get_structure...\n";
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


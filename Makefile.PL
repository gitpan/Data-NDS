
use ExtUtils::MakeMaker;
use 5.001;
use strict;
use warnings;
my %requires = (
                 'Algorithm::Permute'       => '0',
                 'IO::File'                 => '0',
                 'Storable'                 => '0',
                 'Test::More'               => '0',
                 'Test::Pod'                => '0',
                 'Test::Pod::Coverage'      => '0',
               );


WriteMakefile(
        NAME             => 'Data::NDS',
        VERSION          => '3.11',
        ($] >= 5.001
        ? (ABSTRACT=>'routines to work with a perl nested data structure',
           AUTHOR  =>'Sullivan Beck (sbeck@cpan.org)')
        : ()),
        'dist' => {COMPRESS=>'gzip',SUFFIX=>'gz'},
        PL_FILES  => {},
        PREREQ_PM => \%requires,
);

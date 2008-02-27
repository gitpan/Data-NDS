use ExtUtils::MakeMaker;
WriteMakefile(
   NAME => "Data::NDS",
   VERSION_FROM => "NDS.pm",
   ($] >= 5.005
       ? (ABSTRACT=>'routines to work with a perl nested data structure',
          AUTHOR  =>'Sullivan Beck (sbeck@cpan.org)')
       : ()),
  'dist' => {COMPRESS=>'gzip',SUFFIX=>'gz'},
  PREREQ_PM => {
                Carp                    => 0,
                Storable                => 0,
               },
);

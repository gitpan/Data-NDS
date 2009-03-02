
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME             => 'Data::NDS',
	VERSION	         => '3.00',
	($] >= 5.005
	? (ABSTRACT=>'routines to work with a perl nested data structure',
	   AUTHOR  =>'Sullivan Beck (sbeck@cpan.org)')
	: ()),
	'dist' => {COMPRESS=>'gzip',SUFFIX=>'gz'},
        PL_FILES  => {},
	PREREQ_PM => {
		'Algorithm::Permute'  => '0',
		'IO::File'            => '0',
		'Storable'            => '0',
		'Test::More'          => '0',
		'Test::Pod'           => '0',
		'Test::Pod::Coverage' => '0',
	},
);

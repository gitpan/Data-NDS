
use ExtUtils::MakeMaker;

WriteMakefile(
	NAME             => 'Data::NDS',
	VERSION	         => '1.02',
	($] >= 5.005
	? (ABSTRACT=>'routines to work with a perl nested data structure',
	   AUTHOR  =>'Sullivan Beck (sbeck@cpan.org)')
	: ()),
	'dist' => {COMPRESS=>'gzip',SUFFIX=>'gz'},
	PREREQ_PM => {
		'Storable'            => '0',
		'Algorithm::Permute'  => '0',
		'IO::File'            => '0',
		'Test::More'          => '0',
		'Test::Pod'           => '0',
		'Test::Pod::Coverage' => '0',
	},
);

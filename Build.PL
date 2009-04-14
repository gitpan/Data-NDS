
use Module::Build;

my $build = Module::Build->new(
        license            => 'perl',
        dist_version       => '3.10',
        dist_author        => 'Sullivan Beck <sbeck@cpan.org>',
        module_name        => 'Data::NDS',
        dist_abstract      => 'routines to work with a perl nested data structure',
        requires           => {
                'perl'                => '5.6.0',
                'Algorithm::Permute'  => '0',
                'IO::File'            => '0',
                'Storable'            => '0',
        },
        build_requires     => {
        },
        build_recommends   => {
                'Test::More'          => '0',
                'Test::Pod'           => '0',
                'Test::Pod::Coverage' => '0',
        },
        sign               => 1,
);

$build->create_build_script;

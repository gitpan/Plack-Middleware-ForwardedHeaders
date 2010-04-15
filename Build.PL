use Module::Build;
my $build = Module::Build->new(
    module_name        => 'Plack::Middleware::ForwardedHeaders',
    license            => 'perl',
    dynamic_config     => 0,
    create_license     => 1,
    create_readme      => 1,
    create_makefile_pl => 'traditional',
    meta_merge         => {
        resources => {
            bugtracker => 'http://github.com/haarg/Plack-Middleware-ForwardedHeaders/issues',
            repository => 'http://github.com/haarg/Plack-Middleware-ForwardedHeaders/tree',
        },
    },
    requires => {
        'Plack' => 0.9929,
    },
    build_requires => {
        'Test::More' => 0,
    },
);
$build->create_build_script;


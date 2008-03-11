use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new
  ( module_name         => 'Test::Trap',
    license             => 'perl',
    create_makefile_pl  => 'traditional',
    dist_author         => 'Eirik Berg Hanssen <Eirik-Berg.Hanssen@allverden.no>',
    dist_version_from   => 'lib/Test/Trap.pm',
    requires =>
    { 'base'              => 0, # core ...
      'constant'          => 0, # core ...
      'Carp'              => 0,
      'Config'            => 0, # for testing, but core, right?
      'Data::Dump'        => 0,
      'Exporter'          => 0,
      'File::Temp'        => 0,
      'IO::Handle'        => 0,
      'lib'               => 0, # core ...
      'strict'            => 0, # now _that's_ core!
      'Test::Builder'     => 0,
      'Test::More'        => 0,
      'Test::Tester'      => 0.107,   # fails with at least some earlier ones
      'perl'              => '5.6.0', # certainly 5.6.2 ...
      'version'           => 0,
      'warnings'          => 0,
    },
    add_to_cleanup      => [ 'Test-Trap-*' ],
  );

$builder->create_build_script();

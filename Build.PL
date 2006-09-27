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
    { 'Test::Tester'      => 0,
      'Test::More'        => 0,
      'File::Temp'        => 0,
      'Data::Dump'        => 0,
      'version'           => 0,
      'perl'              => '5.6.0', # certainly 5.6.2 ...
    },
    add_to_cleanup      => [ 'Test-Trap-*' ],
  );

$builder->create_build_script();

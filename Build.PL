use strict;
use warnings;
use Module::Build;

my $class = Module::Build->subclass( code => <<'TRICK_EMACS' . <<'END_SUBCLASS' );
TRICK_EMACS

=head1 ACTIONS

=head2 authortest

This runs all the C<xt/author> tests, as well as the ordinary tests,
after making sure that the build, manifest, and distmeta actions have
been taken.

=cut

sub ACTION_authortest {
    my ($self) = @_;

    $self->depends_on('build');
    $self->depends_on('manifest');
    $self->depends_on('distmeta');

    $self->test_files( qw< t xt/author > );
    $self->recursive_test_files(1);

    $self->depends_on('test');

    return;
}

sub ACTION_distdir {
    my ($self) = @_;

    $self->depends_on('authortest');

    return $self->SUPER::ACTION_distdir();
}

END_SUBCLASS

my $builder = $class->new
  ( module_name         => 'Test::Trap',
    license             => 'perl',
    create_makefile_pl  => 'traditional',
    dist_author         => 'Eirik Berg Hanssen <Eirik-Berg.Hanssen@allverden.no>',
    dist_version_from   => 'lib/Test/Trap.pm',
    requires =>
    { 'base'              => 0, # core ...
      'constant'          => 0, # core ...
      'Carp'              => 0,
      'Data::Dump'        => 0,
      'Exporter'          => 0,
      'File::Temp'        => 0,
      'IO::Handle'        => 0,
      'lib'               => 0, # core ...
      'strict'            => 0, # now _that's_ core!
      'Test::Builder'     => 0,
      'Test::More'        => 0,
      'Test::Tester'      => 0.107,   # fails with at least some earlier ones
      'perl'              => '5.6.2',
      'version'           => 0,
      'warnings'          => 0,
    },
    add_to_cleanup      => [ 'Test-Trap-*' ],
  );

$builder->create_build_script();

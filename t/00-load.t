#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/00-*.t" -*-

use Test::More tests => 4;

BEGIN {
  use_ok( 'Test::Trap::Builder::TempFile' );
SKIP: {
    skip 'Lacking PerlIO', 1 unless eval "use PerlIO; 1";
    use_ok( 'Test::Trap::Builder::PerlIO' );
  }
  use_ok( 'Test::Trap::Builder' );
  use_ok( 'Test::Trap' );
}

diag( "Testing Test::Trap $Test::Trap::VERSION, Perl $], $^X" );

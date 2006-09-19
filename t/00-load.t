#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/00-*.t" -*-

use Test::More tests => 2;

BEGIN {
	use_ok( 'Test::Trap::Builder' );
	use_ok( 'Test::Trap' );
}

diag( "Testing Test::Trap $Test::Trap::VERSION, Perl $], $^X" );

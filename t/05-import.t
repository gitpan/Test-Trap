#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/05-*.t" -*-
use Test::More tests => 5;
use strict;
use warnings;

BEGIN {
  use_ok( 'Test::Trap' );
}

eval { Test::Trap->import(qw( trap1 trap2 )) };
like( $@,
      qr/^The Test::Trap module does not export more than one function; import error at ${\__FILE__} line/,
      'Export of two functions',
    );

eval { Test::Trap->import(qw( $trap1 $trap2 )) };
like( $@,
      qr/^The Test::Trap module does not export more than one scalar; import error at ${\__FILE__} line/,
      'Export of two globs',
    );

eval { Test::Trap->import(qw( @bad )) };
like( $@,
      qr/^"\@bad" is not exported by the Test::Trap module; import error at ${\__FILE__} line/,
      'Export of an array',
    );

eval { Test::Trap->import(qw( :no_such_layer )) };
like( $@,
      qr/^Unknown trapper layer "no_such_layer"; import error at ${\__FILE__} line/,
      'Export of an unknown layer',
    );

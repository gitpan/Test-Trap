#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/05-*.t" -*-
use Test::More tests => 8;
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

my %got;
$got{perlio} = eval q{ use PerlIO 'scalar'; 1 };
$got{tempfile} = eval q{ use File::Temp; 1 };

eval { Test::Trap->import(qw( test1 $T1 :stdout(perlio) )) };
like( $@,
      $got{perlio} ?
      qr/\A\z/ :
      qr/^No output layer implementation found for "perlio" at ${\__FILE__} line/,
      'Export of PerlIO implementation :stdout(perlio)',
    );

eval { Test::Trap->import(qw( test2 $T2 :stdout(nosuch;tempfile) )) };
like( $@,
      $got{tempfile} ?
      qr/\A\z/ :
      qr/^\QNo output layer implementation found for ("nosuch", "tempfile") at ${\__FILE__} line\Q/,
      'Export of PerlIO implementation :stdout(nosuch;tempfile)',
    );

eval { Test::Trap->import(qw( test2 $T2 :stdout(nosuch1;nosuch2) )) };
like( $@,
      qr/^\QNo output layer implementation found for ("nosuch1", "nosuch2") at ${\__FILE__} line\Q/,
      'Export of PerlIO implementation :stdout(nosuch1;nosuch2)',
    );


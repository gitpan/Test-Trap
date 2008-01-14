#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/13-*.t" -*-
use Test::More tests => 5;
use strict;
use warnings;

BEGIN {
  use_ok( 'Test::Trap' );
}

() = trap { @_ };
is( $trap->leaveby, 'return', 'We may access @_' );
is_deeply( $trap->return, [], 'Empty @_ in the trap block, please' );

() = trap { $_[1] = 1; @_ };
is( $trap->leaveby, 'return', 'We may modify @_' );
is_deeply( $trap->return, [ undef, 1 ], 'Modified @_ in the trap block' );

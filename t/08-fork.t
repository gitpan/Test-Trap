#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/08-*.t" -*-
use Test::More tests => 8;
use strict;
use warnings;

BEGIN {
  *CORE::GLOBAL::exit = sub(;$) {
    pass("The final test: The outer CORE::GLOBAL::exit is eventually called");
    CORE::exit(@_ ? shift : 0);
  };
}

BEGIN {
  use_ok( 'Test::Trap' );
}

trap { exit };
is( $trap->exit, 0, "Trapped the first exit");
trap {
  *CORE::GLOBAL::exit = sub(;$) {
    pass("The inner CORE::GLOBAL::exit is called from the child");
    CORE::exit(@_ ? shift : 0);
  };
  trap {
    fork;
    exit;
  };
  wait; # let the child finish first
  # Increment the counter correctly ...
  my $Test = Test::More->builder;
  $Test->current_test( $Test->current_test + 1 );
  is( $trap->exit, 0, "Trapped the inner exit");
};
like( $trap->stderr, qr/^Subroutine CORE::GLOBAL::exit redefined at ${\__FILE__} line/, 'Override warning' );

trap {
  trap{
    trap {
      fork;
      exit;
    };
    wait;
    is( $trap->exit, 0, "Trapped the inner exit" );
  }
};
is( $trap->leaveby, 'return', 'Should return just once, okay?' );

exit;

#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/04-*.t" -*-
use Test::More tests => 5;
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
    fail("Should be overridden");
    CORE::exit(@_ ? shift : 0);
  };
  trap { exit };
  is( $trap->exit, 0, "Trapped the inner exit");
};
like( $trap->stderr, qr/^Subroutine (?:CORE::GLOBAL::)?exit redefined at ${\__FILE__} line/, 'Override warning' );

exit;

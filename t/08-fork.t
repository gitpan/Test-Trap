#!perl
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/08-*.t" -*-
use Test::More tests => 15;
use strict;
use warnings;

my $flag;
BEGIN {
  *CORE::GLOBAL::exit = sub(;$) {
    if ($flag) {
      pass("The final test: The outer CORE::GLOBAL::exit is eventually called");
    }
    else {
      fail("The outer CORE::GLOBAL::exit is called too soon!");
    }
    CORE::exit(@_ ? shift : 0);
  };
}

BEGIN {
  use_ok( 'Test::Trap', ':flow:stdout(tempfile):stderr(tempfile):warn' );
}

# check that the setup works -- the exit is still trapped:
trap { exit };
is( $trap->exit, 0, "Trapped the first exit");

# check that the exit from the forked-off process reverts to the inner
# CORE::GLOBAL::exit, not the outer
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
like( $trap->stderr, qr/^Subroutine (?:CORE::GLOBAL::)?exit redefined at ${\__FILE__} line/, 'Override warning' );

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

# Output from forked-off processes?
trap {
  my $me = fork ? 'parent' : 'child';
  print "\u$me print\n";
  warn "\u$me warning\n";
  exit $$ if $me eq 'parent';
  CORE::exit(0);
};
is( $trap->exit, $$, "Trapped the parent exit" );
like( $trap->stdout, qr/^(Parent print\nChild print\n|Child print\nParent print\n)/, 'STDOUT from both processes!' );
like( $trap->stderr, qr/^(Parent warning\nChild warning\n|Child warning\nParent warning\n)/, 'STDERR from both processes!' );
is_deeply( $trap->warn, ["Parent warning\n"], 'Warnings from the parent only' );

# STDERR from forked-off processes, with a closed STDIN & STDOUT?
trap {
  close STDOUT;
  trap {
    my $me = fork ? 'parent' : 'child';
    print "\u$me print\n";
    warn "\u$me warning\n";
    exit $$ if $me eq 'parent';
    CORE::exit(0);
  };
  is( $trap->exit, $$, "Trapped the parent exit" );
  is( $trap->stdout, '', 'STDOUT from both processes is nil -- the handle is closed!' );
  like( $trap->stderr, qr/\A(?=.*^Parent warning$)(?=.*^Child warning$)/ms, 'STDERR from both processes!' );
};


$flag++; # the exit test will now pass -- in the forked-off processes it will fail!
exit;

#!perl -T

use Test::More;
use IO::Handle;
use File::Temp qw( tempfile );
use Data::Dump qw(dump);
use strict;
use warnings;

our $backend; # to be set in the requiring test script ...
BEGIN {
  my $pkg = "Test::Trap::Builder::$backend";
  local $@;
  eval qq{ use $pkg };
  if (exists &{"$pkg\::import"}) {
    plan tests => 1 + 6*10 + 5*3; # 10 runtests; 3 inner_tests
  }
  else {
    plan skip_all => "$backend backend not supported; skipping";
  }
}

# This is an ugly bunch of tests, but for regression's sake, I'll
# leave it as-is.  The problem is that warn() (or rather, the default
# __WARN__ handler) will print on the previous STDERR if the current
# STDERR is closed.

BEGIN {
  use_ok( 'Test::Trap', '$T', lc ":flow:stdout($backend):stderr($backend):warn" );
}

STDERR: {
  close STDERR;
  my ($errfh, $errname) = tempfile;
  open STDERR, '>', $errname;
  STDERR->autoflush(1);
  print STDOUT '';
  sub stderr () { local $/; no warnings 'io'; local *ERR; open ERR, '<', $errname or die; <ERR> }
}

sub diagdie {
  my $msg = shift;
  diag $msg;
  die $msg;
}

my ($noise, $noisecounter) = ('', 0);
sub runtests(&@) { # runs the trap and performs 6 tests
  my($code, $return, $warn, $stdout, $stderr, $desc) = @_;
  my $n = ++$noisecounter . $/;
  warn $n or diagdie "Cannot warn()!";
  STDERR->flush or diagdie "Cannot flush STDERR!";
  print STDERR $n or diagdie "Cannot print on STDERR!";
  STDERR->flush or diagdie "Cannot flush STDERR!";
  $noise .= "$n$n";
  my @r = eval { &trap($code) }; # bypass prototype
  my $e = $@;
SKIP: {
    ok( !$e, "$desc: No internal exception" ) or do {
      diag "Got internal exception: '$e'";
      skip "$desc: Internal exception -- bad state", 5;
    };
    is_deeply( $T->return, $return, "$desc: Return" );
    is_deeply( $T->warn, $warn, "$desc: Warnings" );
    is( $T->stdout, $stdout, "$desc: STDOUT" );
    is( $T->stderr, $stderr, "$desc: STDERR" );
    is( stderr, $noise, ' -- no uncaptured STDERR -- ' );
  }
}

my $inner_trap;
sub inner_tests(@) { # performs 5 tests
  my($return, $warn, $stdout, $stderr, $desc) = @_;
SKIP: {
    ok(eval{$inner_trap->isa('Test::Trap')}, "$desc: The object" )
      or skip 'No inner trap object!', 4;
    is_deeply( $inner_trap->return, $return, "$desc: Return" );
    is_deeply( $inner_trap->warn, $warn, "$desc: Warnings" );
    is( $inner_trap->stdout, $stdout, "$desc: STDOUT" );
    is( $inner_trap->stderr, $stderr, "$desc: STDERR" );
  }
  undef $inner_trap; # catch those simple mistakes.
}

runtests { 5 }
  [5], [],
  '', '',
  'No output';

runtests { my $t; print "Test printing '$t'"; 2}
  [2], ["Use of uninitialized value in concatenation (.) or string at ${\__FILE__} line ${\( __LINE__-1)}.\n"],
  "Test printing ''", "Use of uninitialized value in concatenation (.) or string at ${\__FILE__} line ${\( __LINE__-2)}.\n",
  'Warning';

runtests { close STDERR; my $t; print "Test printing '$t'"; 2}
  [2], ["Use of uninitialized value in concatenation (.) or string at ${\__FILE__} line ${\(__LINE__-1)}.\n"],
  "Test printing ''", '',
  'Warning with closed STDERR';

runtests { warn "Testing stderr trapping\n"; 5 }
  [5], ["Testing stderr trapping\n"],
  '', "Testing stderr trapping\n",
  'warn()';

runtests { close STDERR; warn "Testing stderr trapping\n"; 5 }
  [5], ["Testing stderr trapping\n"],
  '', '',
  'warn() with closed STDERR';

runtests { my @r = trap { warn "Testing stderr trapping\n"; 5 }; $inner_trap = $T; @r}
  [5], [],
  '', '',
  'warn() in inner trap';
inner_tests
  [5], ["Testing stderr trapping\n"],
  '', "Testing stderr trapping\n",
  ' -- the inner trap -- warn()';

runtests { print STDERR "Test printing"; 2}
  [2], [],
  '', 'Test printing',
  'print() on STDERR';

runtests { close STDOUT; print "Testing stdout trapping\n"; 6 }
  [6], ["print() on closed filehandle STDOUT at ${\__FILE__} line ${\(__LINE__-1)}.\n"],
  '', "print() on closed filehandle STDOUT at ${\__FILE__} line ${\(__LINE__-2)}.\n",
  'print() with closed STDOUT';

runtests { close STDOUT; my @r = trap { print "Testing stdout trapping\n"; (5,6)}; $inner_trap = $T; @r }
  [5, 6], [],
  '', '',
  'print() in inner trap with closed STDOUT';
inner_tests
  [5, 6], ["print() on closed filehandle STDOUT at ${\__FILE__} line ${\(__LINE__-5)}.\n"],
  '', "print() on closed filehandle STDOUT at ${\__FILE__} line ${\(__LINE__-6)}.\n",
  ' -- the inner trap -- print() with closed STDOUT';

runtests { close STDERR; my @r = trap { warn "Testing stderr trapping\n"; 2 }; $inner_trap = $T; @r }
  [2], [],
  '', '',
  'warn() in inner trap with closed STDERR';
inner_tests
  [2], ["Testing stderr trapping\n"],
  '', '',
  ' -- the inner trap -- warn() with closed STDERR';

1;

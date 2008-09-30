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
    plan tests => 1 + 6*10 + 5*3 + 1; # 10 runtests; 3 inner_tests
  }
  else {
    plan skip_all => "$backend backend not supported; skipping";
  }
}

# This is an ugly bunch of tests, but for regression's sake, I'll
# leave it as-is.

# One problem is that warn() (or rather, the default __WARN__ handler)
# will print on the previous STDERR if the current STDERR is closed.

# Another problem is that the __WARN__ handler has not always been
# properly restored on exit from a trap.  Ouch.

BEGIN {
  use_ok( 'Test::Trap', '$T', lc ":flow:stdout($backend):stderr($backend):warn" );
}

STDERR: {
  close STDERR;
  my ($errfh, $errname) = tempfile( UNLINK => 1 );
  open STDERR, '>', $errname;
  STDERR->autoflush(1);
  print STDOUT '';
  sub stderr () { local $/; no warnings 'io'; local *ERR; open ERR, '<', $errname or die; <ERR> }
  END { close STDERR; close $errfh }
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
  $warn = do { local $" = "[^`]*`"; qr/\A@$warn[^`]*\z/ };
  my @r = eval { &trap($code) }; # bypass prototype
  my $e = $@;
SKIP: {
    ok( !$e, "$desc: No internal exception" ) or do {
      diag "Got internal exception: '$e'";
      skip "$desc: Internal exception -- bad state", 5;
    };
    is_deeply( $T->return, $return, "$desc: Return" );
    like( join("`", @{$T->warn}), $warn, "$desc: Warnings" );
    is( $T->stdout, $stdout, "$desc: STDOUT" );
    like( $T->stderr, $stderr, "$desc: STDERR" );
    is( stderr, $noise, ' -- no uncaptured STDERR -- ' );
  }
}

my $inner_trap;
sub inner_tests(@) { # performs 5 tests
  my($return, $warn, $stdout, $stderr, $desc) = @_;
  $warn = do { local $" = "[^`]*`"; qr/\A@$warn[^`]*\z/ };
SKIP: {
    ok(eval{$inner_trap->isa('Test::Trap')}, "$desc: The object" )
      or skip 'No inner trap object!', 4;
    is_deeply( $inner_trap->return, $return, "$desc: Return" );
    like( join("`", @{$inner_trap->warn}), $warn, "$desc: Warnings" );
    is( $inner_trap->stdout, $stdout, "$desc: STDOUT" );
    like( $inner_trap->stderr, $stderr, "$desc: STDERR" );
  }
  undef $inner_trap; # catch those simple mistakes.
}

runtests { 5 }
  [5], [],
  '', qr/\A\z/,
  'No output';

runtests { my $t; print "Test printing '$t'"; 2}
  [2], [ qr/^Use of uninitialized value.* in concatenation \Q(.) or string at / ],
  "Test printing ''", qr/^Use of uninitialized value.* in concatenation \Q(.) or string at /,
  'Warning';

runtests { close STDERR; my $t; print "Test printing '$t'"; 2}
  [2], [ qr/^Use of uninitialized value.* in concatenation \Q(.) or string at / ],
  "Test printing ''", qr/\A\z/,
  'Warning with closed STDERR';

runtests { warn "Testing stderr trapping\n"; 5 }
  [5], [ qr/^Testing stderr trapping$/ ],
  '', qr/^Testing stderr trapping$/,
  'warn()';

runtests { close STDERR; warn "Testing stderr trapping\n"; 5 }
  [5], [ qr/^Testing stderr trapping$/ ],
  '', qr/\A\z/,
  'warn() with closed STDERR';

runtests {
  warn "Outer 1st\n";
  my @r = trap { warn "Testing stderr trapping\n"; 5 };
  binmode(STDERR); # XXX: masks a real weakness -- we do not simply restore the original!
  $inner_trap = $T;
  warn "Outer 2nd\n";
  @r
} [5], [ qr/Outer 1st/, qr/Outer 2nd/ ],
  '', qr/^Outer 1st\nOuter 2nd$/,
  'warn() in both traps';
inner_tests
  [5], [ qr/^Testing stderr trapping$/ ],
  '', qr/^Testing stderr trapping$/,
  ' -- the inner trap -- warn()';

runtests { print STDERR "Test printing"; 2}
  [2], [],
  '', qr/^Test printing\z/,
  'print() on STDERR';

runtests { close STDOUT; print "Testing stdout trapping\n"; 6 }
  [6], [ qr/^print\Q() on closed filehandle STDOUT at / ],
  '', qr/^print\Q() on closed filehandle STDOUT at /,
  'print() with closed STDOUT';

runtests { close STDOUT; my @r = trap { print "Testing stdout trapping\n"; (5,6) }; $inner_trap = $T; @r }
  [5, 6], [],
  '', qr/\A\z/,
  'print() in inner trap with closed STDOUT';
inner_tests
  [5, 6], [ qr/^print\Q() on closed filehandle STDOUT at / ],
  '', qr/^print\Q() on closed filehandle STDOUT at /,
  ' -- the inner trap -- print() with closed STDOUT';

runtests { close STDERR; my @r = trap { warn "Testing stderr trapping\n"; 2 }; $inner_trap = $T; @r }
  [2], [],
  '', qr/\A\z/,
  'warn() in inner trap with closed STDERR';
inner_tests
  [2], [ qr/^Testing stderr trapping$/ ],
  '', qr/\A\z/,
  ' -- the inner trap -- warn() with closed STDERR';

# regression test for the ', <$fh> line 1.' bug:
trap {
    trap {};
    warn "no newline";
};
unlike $T->stderr, qr/, \S+ line 1\./, 'No "<$f> line ..." stuff, please';

1;

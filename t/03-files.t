#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/03-*.t" -*-
use Test::More tests => 1 + 5*11;
use IO::Handle;
use strict;
use warnings;

# This is an ugly bunch of tests, but for regression's sake, I'll
# leave it as-is.  The problem is that warn() will print on the
# previous STDERR if the current STDERR is closed.

BEGIN {
  use_ok( 'Test::Trap', '$T' );
}

my ($noise, $noisecounter);
sub _noise() {
  ++$noisecounter;
  my $n = "$noisecounter\n";
  warn $n;
  print STDERR $n;
  STDERR->flush;
  die if STDERR->error;
  $noise .= "$n$n";
}

close STDERR;
my $buffer = '';
open STDERR, '>', \$buffer or die;

_noise;
my @r = trap { print STDERR "Test printing"; 2};
is_deeply( $T->return, [2], 'Returns 2' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
is( $T->stderr, 'Test printing', 'Should trap "Test printing" on STDERR' );
is_deeply( $T->warn, [], 'No warnings' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { close STDERR; my $t; print "Test printing '$t'"; 2};
is_deeply( $T->return, [2], 'Returns 2' );
is( $T->stdout, "Test printing ''", 'Trapped STDOUT' );
is( $T->stderr, '', 'Should trap nothing on STDERR' );
is_deeply( $T->warn, ["Use of uninitialized value in concatenation (.) or string at ${ \ __FILE__ } line ${ \ ( __LINE__ - 4 ) }.\n"], 'One warning' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { 5 };
is_deeply( $T->return, [5], 'Returns 5' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
is( $T->stderr, '', 'Should trap nothing on STDERR' );
is_deeply( $T->warn, [], 'No warnings' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { warn "Testing stderr trapping\n"; 5 };
is_deeply( $T->return, [5], 'Returns 5' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
is( $T->stderr, "Testing stderr trapping\n", 'Should trap a warning on STDERR' );
is_deeply( $T->warn, ["Testing stderr trapping\n"], 'One warning' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { close STDERR; warn "Testing stderr trapping\n"; 5 };
is_deeply( $T->return, [5], 'Returns 5' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
is( $T->stderr, '', 'Should trap nothing on STDERR' );
is_deeply( $T->warn, ["Testing stderr trapping\n"], 'One warning' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { trap { warn "Testing stderr trapping\n"; 5 } };
is_deeply( $T->return, [5], 'Returns 5' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
is( $T->stderr, '', 'Should trap nothing on STDERR' );
is_deeply( $T->warn, [], 'No warnings' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { my $t; print "Test printing '$t'"; 2};
is_deeply( $T->return, [2], 'Returns 2' );
is( $T->stdout, "Test printing ''", 'Trapped STDOUT' );
like( $T->stderr, qr/^Use of uninitialized value in concatenation \Q(.)\E or string at ${ \ __FILE__ }/, 'Should trap a warning on STDERR' );
is_deeply( $T->warn, ["Use of uninitialized value in concatenation (.) or string at ${ \ __FILE__ } line ${ \ ( __LINE__ - 4 ) }.\n"], 'One warning' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
my $r = trap { close STDERR; my $t = trap { warn "Testing stderr trapping\n"; 2 }; $T };
# outer
is_deeply( $T->return, [$r], 'Returns a scalar' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
is( $T->stderr, '', 'Should trap nothing on STDERR' );
is_deeply( $T->warn, [], 'No warnings' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
# ... continuing on the previous block ...
# inner
is_deeply( $r->return, [2], 'Returns 2' );
is( $r->stdout, '', 'Should trap nothing on STDOUT' );
is( $r->stderr, '', 'Should trap nothing on STDERR' );
is_deeply( $r->warn, ["Testing stderr trapping\n"], 'One warning' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { close STDOUT; print "Testing stdout trapping\n"; 6 };
is_deeply( $T->return, [6], 'Returns 6' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
like( $T->stderr, qr/^print\(\) on closed filehandle STDOUT at ${ \ __FILE__ }/, 'Should trap a warning on STDERR' );
is_deeply( $T->warn, ["print() on closed filehandle STDOUT at ${ \ __FILE__ } line ${ \ ( __LINE__ - 4 ) }.\n"], 'One warning' );
is( $buffer, $noise, 'No uncaptured STDERR' );

_noise;
@r = trap { close STDOUT; trap { print "Testing stdout trapping\n"; (5,6)}; };
is_deeply( $T->return, [5,6], 'Returns 5, 6' );
is( $T->stdout, '', 'Should trap nothing on STDOUT' );
is( $r->stderr, '', 'Should trap nothing on STDERR' );
is_deeply( $T->warn, [], 'No warnings' );
is( $buffer, $noise, 'No uncaptured STDERR' );

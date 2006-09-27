#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/06-*.t" -*-
use Test::More tests => 5+2 + 10*5;
use IO::Handle;
use File::Temp qw( tempfile );
use strict;
use warnings;

BEGIN {
  use_ok( 'Test::Trap', '$D', 'default' );
}

BEGIN {
  use_ok( 'Test::Trap', '$R', 'raw', ':flow' );
}

BEGIN {
  use_ok( 'Test::Trap', '$M', 'mixed', ':raw:warn:stderr:stdout:exit:die' );
}

local @ARGV; # in case some harness wants to mess with it ...
my @argv = ('A');
BEGIN {
  # special -- a localized @ARGV, setting properties inargv and outargv on return:
  use_ok( 'Test::Trap', '$S', 'special', ':default', $_ ) for sub {
    my $self = shift;
    my $next = pop;
    local *ARGV = \@argv;
    $self->{inargv} = [@argv];
    $self->$next(@_);
    $self->{outargv} = [@argv];
  };
}

BEGIN {
  use_ok( 'Test::Trap', '$W', 'warntrap', ':flow:warn' );
}

STDOUT: {
  close STDOUT;
  my ($outfh, $outname) = tempfile;
  open STDOUT, '>', $outname;
  STDOUT->autoflush(1);
  print STDOUT '';
  sub stdout () { local $/; open OUT, '<', $outname or die; <OUT> }
}

STDERR: {
  close STDERR;
  my ($errfh, $errname) = tempfile;
  open STDERR, '>', $errname;
  STDERR->autoflush(1);
  print STDOUT '';
  sub stderr () { local $/; open ERR, '<', $errname or die; <ERR> }
}

is( stdout, '', 'No untrapped STDOUT' );
is( stderr, '', 'No untrapped STDERR' );

default { print "Hello"; warn "Hi!\n"; push @ARGV, 'D'; exit 1 };
is( $D->exit, 1, '&default' );
is( $D->stdout, "Hello", '.' );
is( $D->stderr, "Hi!\n", '.' );
is_deeply( $D->warn, ["Hi!\n"], '.' );
ok( !exists $D->{inargv}, '.' );
ok( !exists $D->{outargv}, '.' );
is_deeply( \@ARGV, ['D'], '.' );
is_deeply( \@argv, ['A'], '.' );
is( stdout, '', '.' );
is( stderr, '', '.' );

local $D; # guard me against cut-and-paste errors

raw { print "Hello"; warn "Hi!\n"; push @ARGV, 'R'; exit 1 };
is( $R->exit, 1, '&raw' );
is( $R->stdout, undef, '.' );
is( $R->stderr, undef, '.' );
is_deeply( $R->warn, undef, '.' );
ok( !exists $R->{inargv}, '.' );
ok( !exists $R->{outargv}, '.' );
is_deeply( \@ARGV, ['D', 'R'], '.' );
is_deeply( \@argv, ['A'], '.' );
is( stdout, "Hello", '.' );
is( stderr, "Hi!\n", '.' );
local $R; # guard me against cut-and-paste errors

mixed { print "Hello"; warn "Hi!\n"; push @ARGV, 'M'; exit 1 };
is( $M->exit, 1, '&default' );
is( $M->stdout, "Hello", '.' );
is( $M->stderr, "Hi!\n", '.' );
is_deeply( $M->warn, ["Hi!\n"], '.' );
ok( !exists $M->{inargv}, '.' );
ok( !exists $M->{outargv}, '.' );
is_deeply( \@ARGV, ['D', 'R', 'M'], '.' );
is_deeply( \@argv, ['A'], '.' );
is( stdout, "Hello", '.' );
is( stderr, "Hi!\n", '.' );

local $M; # guard me against cut-and-paste errors

special { print "Hello"; warn "Hi!\n"; push @ARGV, 'S'; exit 1 };
is( $S->exit, 1, '&special' );
is( $S->stdout, "Hello", '.' );
is( $S->stderr, "Hi!\n", '.' );
is_deeply( $S->warn, ["Hi!\n"], '.' );
is_deeply( $S->{inargv}, ['A'], '.' );
is_deeply( $S->{outargv}, ['A', 'S'], '.' );
is_deeply( \@ARGV, ['D', 'R', 'M'], '.' );
is_deeply( \@argv, ['A', 'S'], '.' );
is( stdout, "Hello", '.' );
is( stderr, "Hi!\n", '.' );

local $S; # guard me against cut-and-paste errors

warntrap { print "Hello"; warn "Hi!\n"; push @ARGV, 'W'; exit 1 };
is( $W->exit, 1, '&special' );
is( $W->stdout, undef, '.' );
is( $W->stderr, undef, '.' );
is_deeply( $W->warn, ["Hi!\n"], '.' );
ok( !exists $W->{inargv}, '.' );
ok( !exists $W->{outargv}, '.' );
is_deeply( \@ARGV, ['D', 'R', 'M', 'W'], '.' );
is_deeply( \@argv, ['A', 'S'], '.' );
is( stdout, "Hello" x 2, '.' );
is( stderr, "Hi!\n" x 2, '.' );

local $W; # guard me against cut-and-paste errors

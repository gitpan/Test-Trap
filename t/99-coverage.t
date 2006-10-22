#!perl
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/99-*.t" -*-
use Test::More tests => 1;
use strict;
use warnings;

# Tests for the purpose of shutting up Devel::Cover about some stuff
# that really is tested.  Like, trust me already?

my $CURRENT; # access the internals
sub CURRENT { $CURRENT = shift; $CURRENT->Next }
use Test::Trap qw(:default), \&CURRENT;

my $early_exit = 1;
END {
  ok($early_exit, 'Failing to raise an exception: Early exit');
}
trap {
  $CURRENT->{__exception} = sub { return };
  $CURRENT->Exception("Failing");
};
undef $early_exit;

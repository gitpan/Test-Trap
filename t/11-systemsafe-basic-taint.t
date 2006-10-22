#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/11-systemsafe-basic-taint.t" -*-
use Test::More;
use strict;
use warnings;

use Config;

# If Win32, fork() is done with threads, so we need various things
if ( $^O =~ /^(?:MSWin32|NetWare|WinCE)\z/ ) {
  plan skip_all => "Win32 fork() -- covered by t/11-systemsafe-basic-no-taint.t";
}
elsif (!$Config{d_fork}) {
  plan skip_all => 'Fork tests are irrelevant without fork()';
}

use lib '.';
require 't/11-systemsafe-basic.pl';

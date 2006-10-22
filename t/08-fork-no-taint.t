#!perl
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/08-fork-no-taint.t" -*-
use Test::More;
use strict;
use warnings;

use Config;

# Thank you, http://search.cpan.org/src/DAGOLDEN/Class-InsideOut-1.02/t/05_forking.t

# If Win32, fork() is done with threads, so we need various things
if ( $^O =~ /^(?:MSWin32|NetWare|WinCE)\z/ ) {

  # don't run this at all under Devel::Cover
  if ( $ENV{HARNESS_PERL_SWITCHES} &&
       $ENV{HARNESS_PERL_SWITCHES} =~ /Devel::Cover/ ) {
    plan skip_all => "Devel::Cover not compatible with Win32 pseudo-fork";
  }

  # skip if threads not available for some reasons
  if ( ! $Config{useithreads} ) {
    plan skip_all => "Win32 fork() support requires threads";
  }

  # skip if perl < 5.8
  if ( $] < 5.008 ) {
    plan skip_all => "Win32 fork() support requires perl 5.8";
  }
}
elsif (!$Config{d_fork}) {
  plan skip_all => 'Fork tests are irrelevant without fork()';
}
else {
  plan skip_all => "Real fork() -- covered by 08-fork-taint.t";
}


use lib '.';
require 't/08-fork.pl';

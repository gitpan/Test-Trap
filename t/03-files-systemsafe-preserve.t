#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/03-*systemsafe-preserve.t" -*-

use strict;
use warnings;

our $strategy;
$strategy = 'systemsafe-preserve';
# Pull a fast one to run the horrible legacy tests for this layer as well, as long as PerlIO is available:
if (eval qq{ use PerlIO (); 1 }) {
  no strict 'refs';
  *{"Test::Trap::Builder::$strategy\::import"} = sub {};
}

use lib '.';
require 't/03-files.pl';

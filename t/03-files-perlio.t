#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/03-*perlio.t" -*-

use strict;
use warnings;

our $backend;
$backend = 'PerlIO';

use lib '.';
require 't/03-files.pl';
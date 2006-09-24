#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/03-*tempfile.t" -*-

use strict;
use warnings;

our $backend;
$backend = 'TempFile';

use lib '.';
require 't/03-files.pl';

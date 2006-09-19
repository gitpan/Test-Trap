# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/kwalitee.t" -*-
use Test::More;

eval { require Test::Kwalitee; Test::Kwalitee->import() };

plan( skip_all => 'Test::Kwalitee not installed; skipping' ) if $@;

#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/01-*.t" -*-
use Test::More tests => 2 + 8*9;
use strict;
use warnings;

BEGIN {
  use_ok( 'Test::Trap', 'trap', '$trap' );
}

my @x = qw( Example text );

my $r = trap { @x };
is( $trap->leaveby, 'return', ' --==--  Return in scalar context  --==-- ' );
ok( !$trap->list, 'Not list context');
ok( $trap->scalar, 'Scalar context');
ok( !$trap->void, 'Not void context');
is( $r, 2, 'Scalar context return' );
is_deeply( $trap->return, [$r], 'Trapped scalar context return: $r = 2' );
is( $trap->die, undef, 'No exception $trap');
is( $trap->exit, undef, 'No exit trapped');

my @r = trap { @x };
is( $trap->leaveby, 'return', ' --==--  Return in list context  --==-- ' );
ok( $trap->list, 'List context');
ok( !$trap->scalar, 'Not scalar context');
ok( !$trap->void, 'Not void context');
is_deeply( \@r, \@x, 'List context return');
is_deeply( $trap->return, \@r, 'Trapped list context return: @r = @x' );
is( $trap->die, undef, 'No exception trapped');
is( $trap->exit, undef, 'No exit trapped');

trap { $r = defined wantarray ? 'non-void' : 'void' };
is( $trap->leaveby, 'return', ' --==--  Return in void context  --==-- ' );
ok( !$trap->list, 'Not list context');
ok( !$trap->scalar, 'Not scalar context');
ok( $trap->void, 'Void context');
is( $r, 'void', 'Extra void test' );
is_deeply( $trap->return, [], 'Trapped void context "return"' );
is( $trap->die, undef, 'No exception trapped');
is( $trap->exit, undef, 'No exit trapped');

$r = trap { die "My bad 1\n" };
is( $trap->leaveby, 'die', ' --==--  Die in scalar context  --==-- ' );
ok( !$trap->list, 'Not list context');
ok( $trap->scalar, 'Scalar context');
ok( !$trap->void, 'Not void context');
is( $r, undef, 'Dying scalar context return: $r = undef' );
is_deeply( $trap->return, undef, 'Trapped dying scalar context return: none' );
is( $trap->die, "My bad 1\n", 'Trapped exception' );
is( $trap->exit, undef, 'No exit trapped');

@r = trap { die "My bad 2\n" };
is( $trap->leaveby, 'die', ' --==--  Die in list context  --==-- ' );
ok( $trap->list, 'List context');
ok( !$trap->scalar, 'Not scalar context');
ok( !$trap->void, 'Not void context');
is_deeply( \@r, [], 'Dying list context return: @r = ()' );
is_deeply( $trap->return, undef, 'Trapped dying list context return: none' );
is( $trap->die, "My bad 2\n", 'Trapped exception' );
is( $trap->exit, undef, 'No exit trapped');

trap { $r = defined wantarray ? 'non-void' : 'void'; die "My bad 3\n" };
is( $trap->leaveby, 'die', ' --==--  Die in void context  --==-- ' );
ok( !$trap->list, 'Not list context');
ok( !$trap->scalar, 'Not scalar context');
ok( $trap->void, 'Void context');
is( $r, 'void', 'Extra void test' );
is_deeply( $trap->return, undef, 'Trapped dying void context "return"' );
is( $trap->die, "My bad 3\n", 'Trapped exception' );
is( $trap->exit, undef, 'No exit trapped');

$r = trap { exit 42 };
is( $trap->leaveby, 'exit', ' --==--  Exit in scalar context  --==-- ' );
ok( !$trap->list, 'Not list context');
ok( $trap->scalar, 'Scalar context');
ok( !$trap->void, 'Not void context');
is( $r, undef, 'Exiting scalar context return: $r = undef' );
is_deeply( $trap->return, undef, 'Trapped exiting scalar context return: none' );
is( $trap->die, undef, 'No exception trapped' );
is( $trap->exit, 42, 'Trapped exit 42' );

@r = trap { exit };
is( $trap->leaveby, 'exit', ' --==--  Exit in list context  --==-- ' );
ok( $trap->list, 'List context');
ok( !$trap->scalar, 'Not scalar context');
ok( !$trap->void, 'Not void context');
is_deeply( \@r, [], 'Exiting list context return: @r = ()' );
is_deeply( $trap->return, undef, 'Trapped exiting list context return: none' );
is( $trap->die, undef, 'No exception trapped' );
is( $trap->exit, 0, 'Trapped exit 0' );

trap { $r = defined wantarray ? 'non-void' : 'void'; my @x = qw( a b c d ); exit @x };
is( $trap->leaveby, 'exit', ' --==--  Exit in void context  --==-- ' );
ok( !$trap->list, 'Not list context');
ok( !$trap->scalar, 'Not scalar context');
ok( $trap->void, 'Void context');
is( $r, 'void', 'Extra void test' );
is_deeply( $trap->return, undef, 'Trapped exiting void context "return": none' );
is( $trap->die, undef, 'No exception trapped' );
is( $trap->exit, 4, 'Trapped exit 4' );

exit 0;

my $tricky = 1;

END {
  is($tricky, undef, ' --==-- END block past exit --==-- ');
}

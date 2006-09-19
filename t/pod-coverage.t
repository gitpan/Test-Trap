#!perl -T
# -*-mode:cperl-*-

use Test::More;
eval "use Test::Pod::Coverage 1.04";
plan skip_all => "Test::Pod::Coverage 1.04 required for testing POD coverage" if $@;
my $layer =
  qr/ ^ layer:
    (?: raw
      | die
      | exit
      | flow
      | stdout
      | stderr
      | warn
      | default
      ) $
    /x;
my $test =
  qr/ ^
    (?: leaveby
      | exit
      | die
      | stdout
      | stderr
      | wantarray
      | return
      | warn
      | list
      | scalar
      | void
      ) _
    (?: ok
      | nok
      | is
      | isnt
      | like
      | unlike
      | cmp_ok
      | is_deeply
      ) $
    /x;
all_pod_coverage_ok({ trustme => [$layer, $test] });


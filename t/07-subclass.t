#!perl -T
# -*- mode: cperl ; compile-command: "cd .. ; ./Build ; prove -vb t/07-*.t" -*-
use Test::More tests => 4 + 9*2 + 6;
use IO::Handle;
use Time::HiRes qw/alarm/;
use strict;
use warnings;

use Test::Trap::Builder;
my $Builder; BEGIN { $Builder = Test::Trap::Builder->new }

local @ARGV; # in case some harness wants to mess with it ...
my @argv = ('A');
BEGIN {
  package TT::subclass;
  use base 'Test::Trap';
  $Builder->layer( argv => $_ ) for sub {
    my $self = shift;
    my $next = pop;
    local *ARGV = \@argv;
    $self->{inargv} = [@argv];
    $self->$next(@_);
    $self->{outargv} = [@argv];
  };
  $Builder->accessor( is_array => 1, simple => [qw/inargv outargv/] );
  $Builder->accessor( flexible =>
		      { argv => sub {
			  $_[1] && $_[1] !~ /in/i ? $_[0]{outargv} : $_[0]{inargv};
			},
		      },
		    );
  $Builder->test_method( can => 1, 1, $_ ) for sub {
    my ($got, $methods) = @_;
    @_ = ($got, @$methods);
    goto &Test::More::can_ok;
  };
  # Hack! Make perl think we have successfully required this package,
  # so that we can "use" it, even though it can't be found:
  $INC{'TT/subclass.pm'} = 'Hack!';
}

BEGIN {
  package TT::examples;
  use base 'Test::Trap';
  use Time::HiRes qw/ualarm/;
  my $B = Test::Trap::Builder->new;

  # example (layer:timeout):
  $B->layer( timeout => $_ ) for sub {
    my $self = shift; my $next = pop;
    eval {
      local $SIG{ALRM} = sub {
	$self->{timeout} = 1; # simple truth
	$SIG{ALRM} = sub {die};
	die;
      };
      ualarm 1000, 1; # one second max, then die repeatedly!
      $self->$next(@_);
    };
    alarm 0;
    if ($self->{timeout}) {
      $self->{leaveby} = 'timeout';
      delete $self->{$_} for qw/ die exit return /;
    }
  };
  $B->accessor( is_leaveby => 1,
		simple => ['timeout'],
	      );

  # example (layer:simpletee):
  $B->layer( simpletee => $_ ) for sub {
    my $self = shift; my $next = pop;
    for (qw/ stdout stderr /) {
      next unless exists $self->{$_};
      die "Too late to tee $_";
    }
    $self->$next(@_);
    print STDOUT $self->{stdout} if exists $self->{stdout};
    print STDERR $self->{stderr} if exists $self->{stderr};
  };
  # no accessor for this layer

  $B->multi_layer(flow => qw/ raw die exit timeout /);
  $B->multi_layer(default => qw/ flow stdout stderr warn simpletee /);

  $B->test_method( cmp_ok => 1, 2, \&Test::More::cmp_ok );

  # Hack! Make perl think we have successfully required this package,
  # so that we can "use" it, even though it can't be found:
  $INC{'TT/examples.pm'} = 'Hack!';
}

BEGIN {
  # Insert s'mores into Test::Trap itself ... not clean, but a nice
  # quick thing to be able to do, in need:
  package Test::Trap;
  my $B = Test::Trap::Builder->new;
  $B->accessor( flexible =>
		{ leavewith => sub {
		    my $self = shift;
		    my $leaveby = $self->leaveby;
		    $self->$leaveby;
		  },
		},
	      );
  $B->test_method( pass => 0, 0, sub { shift; goto &Test::More::pass } );
}

BEGIN {
  use_ok( 'Test::Trap', '$D', 'default' );
}

BEGIN {
  use_ok( 'TT::subclass', '$S', 'subclass', ':argv' );
}

BEGIN {
  use_ok( 'TT::examples', '$E', 'example' );
}

BEGIN {
  default {
    package TT::badclass;
    use base 'Test::Trap';
    $Builder->multi_layer( trouble => qw( warn no_such_layer ) );
  };
  like( $D->die,
	qr/^Unknown trapper layer "no_such_layer"; bad multi_layer at ${\__FILE__} line/,
	'Bad definition',
      );
}

default { print "Hello"; warn "Hi!\n"; push @ARGV, 'D'; exit 1 };
is( $D->exit, 1, '&default' );
is( $D->stdout, "Hello", '.' );
is( $D->stderr, "Hi!\n", '.' );
is_deeply( $D->warn, ["Hi!\n"], '.' );
ok( !exists $D->{inargv}, '.' );
ok( !exists $D->{outargv}, '.' );
is_deeply( \@ARGV, ['D'], '.' );
is_deeply( \@argv, ['A'], '.' );
() = default { $D->outargv };
like( $D->die, qr/^Can\'t locate object method "outargv" via package "Test::Trap" at /, '.' );

local $D; # guard me against cut-and-paste errors

subclass { print "Hello"; warn "Hi!\n"; push @ARGV, 'S'; exit 1 };
is( $S->exit, 1, '&subclass' );
is( $S->stdout, "Hello", '.' );
is( $S->stderr, "Hi!\n", '.' );
is_deeply( $S->warn, ["Hi!\n"], '.' );
is_deeply( $S->{inargv}, ['A'], '.' );
is_deeply( $S->{outargv}, ['A', 'S'], '.' );
is_deeply( \@ARGV, ['D'], '.' );
is_deeply( \@argv, ['A', 'S'], '.' );
() = subclass { $S->outargv };
is_deeply( $S->return(0), \@argv, '.' );

local $S; # guard me against cut-and-paste errors

# Protect against tainted PATH &c ...
ENVING: {
  local $ENV{PATH} = '';
  local $ENV{BASH_ENV} = '';
  my ($PERL) = $^X =~ /^([\w.\/:-]+)$/;
  skip 5, 'Odd perl path' unless $PERL;
  () = example { eval { fork or exec $PERL, '-e', 'sleep 2' or die $!; wait; }; die $@ if $@; exit 5; };
  is( $E->timeout, 1, '&example' );
  is( $E->leaveby, 'timeout', '.' );
  is( $E->die, undef, '.' );
  is( $E->exit, undef, '.' );
  isnt( $E->return(0), -1, '.' );
  ok( wait > 0, '.' );
}

local $E; # guard me against cut-and-paste errors

package Test::Trap;

use version; $VERSION = qv('0.0.20');

use strict;
use warnings;
use Carp qw( croak );
use IO::Handle;
use Data::Dump qw(dump);
use Test::Trap::Builder qw( :methods );

my $B = Test::Trap::Builder->new;

sub import {
  my $module = shift;
  my $callpkg = caller;
  my (@function, @scalar, @layer);
  while (@_) {
    my $sym = shift;
    UNIVERSAL::isa($sym, 'CODE') ? push @layer,    $sym :
    $sym =~ s/^://               ? push @layer,    split/:/, $sym :
    $sym =~ s/^\$//              ? push @scalar,   $sym :
    $sym !~ m/^[@%*]/            ? push @function, $sym :
    croak qq["$sym" is not exported by the $module module];
  }
  if (@function > 1) {
    croak qq[The $module module does not export more than one function];
  }
  if (@scalar > 1) {
    croak qq[The $module module does not export more than one scalar];
  }
  my $function = @function ? $function[0] : 'trap';
  my $scalar = @scalar ? $scalar[0] : 'trap';
  @layer = $B->layer_implementation($module, default => @layer);
  no strict 'refs';
  my $gref = \*{"$callpkg\::$scalar"};
  *$gref = \ do { my $x = bless {}, $module };
  *{"$callpkg\::$function"} = sub (&) {
    $B->trap($module, $gref, \@layer, shift);
  }
}

####################
#  Standard layers #
####################

# The big one: trapping exits correctly:
EXIT_LAYER: {
  # A versatile &CORE::GLOBAL::exit candidate:
  sub _global_exit (;$) {
    my $exit = @_ ? 0+shift : 0;
    ___exit($exit) if exists &___exit;
    CORE::exit($exit);
  };

  # Need to have &CORE::GLOBAL::exit set, one way or the other,
  # before any code to be trapped is compiled:
  *CORE::GLOBAL::exit = \&_global_exit unless exists &CORE::GLOBAL::exit;

  # And at last, the layer for exits:
  $B->layer(exit => $_) for sub {
    my $self = shift;
    # in case someone else is messing with exit:
    my $pid = $$;
    my $outer = \&CORE::GLOBAL::exit;
    undef $outer if $outer == \&_global_exit;
    local *___exit;
    {
      no warnings 'redefine';
      *___exit = sub {
	if ($$ != $pid) {
	  return $outer->(@_) if $outer;
	  # XXX: This is fuzzy ... how to test this right?
	  CORE::exit(shift);
	}
	$self->{exit} = shift;
	$self->{leaveby} = 'exit';
	goto EXITING;
      };
    }
    local *CORE::GLOBAL::exit;
    *CORE::GLOBAL::exit = \&_global_exit;
    $self->Next;
  EXITING:
    return;
  };
}

# The other layers and standard accessors:

# Note: :raw is a terminating layer -- it does not call any lower
# layer, but is the layer responsible for calling the actual code!
$B->layer(raw => $_) for sub {
  my $self = shift;
  my $wantarray = $self->{wantarray};
  my @return;
  unless (defined $wantarray) { $self->Run }
  elsif ($wantarray) { @return = $self->Run }
  else { @return = scalar $self->Run }
  $self->{return} = \@return;
  $self->{leaveby} = 'return';
};

# A simple layer for exceptions:
$B->layer(die => $_) for sub {
  my $self = shift;
  local *@;
  return if eval { $self->Next; 1 };
  $self->{die} = $@;
  $self->{leaveby} = 'die';
};

# Layers for STDOUT and STDERR, from the factory:
$B->output_layer( stdout => \*STDOUT );
$B->output_layer( stderr => \*STDERR );
$B->default_output_layer_backends( qw/ tempfile perlio / );
BEGIN {
  # Make availible some backends:
  use Test::Trap::Builder::TempFile;
  eval q{ use Test::Trap::Builder::PerlIO }; # optional
  eval q{ use Test::Trap::Builder::SystemSafe }; # optional
}

# A simple layer for warnings:
$B->layer(warn => $_) for sub {
  my $self = shift;
  my @warn;
  # Can't local($SIG{__WARN__}) because of a perl bug with local() on
  # scalar values under the Windows fork() emulation -- work around:
  my %sig = %SIG;
  defined $sig{$_} or delete $sig{$_} for keys %sig;
  local %SIG;
  %SIG = %sig;
  $SIG{__WARN__} = sub {
    my $w = shift;
    push @warn, $w;
    print STDERR $w if defined fileno STDERR;
  };
  $self->{warn} = \@warn;
  $self->Next;
};

# Pseudo-layers:
$B->multi_layer(flow => qw/ raw die exit /);
$B->multi_layer(default => qw/ flow stdout stderr warn /);

########################
#  Standard accessors  #
########################

$B->accessor( simple => [ qw/ leaveby stdout stderr wantarray / ],
	      flexible =>
	      { list => sub {
		  $_[0]{wantarray};
		},
		scalar => sub {
		  my $x = $_[0]{wantarray};
		  !$x and defined $x;
		},
		void => sub {
		  not defined $_[0]{wantarray};
		},
	      },
	    );
$B->accessor( is_leaveby => 1,
	      simple => [ qw/ exit die / ],
	    );
$B->accessor( is_array => 1,
	      simple => [ qw/ warn / ],
	    );
$B->accessor( is_array => 1,
	      is_leaveby => 1,
	      simple => [ qw/ return / ],
	    );

##################################################
# Standard tests
#                             use index for arrays
#                             |  test name index
#                name         |  |  implementation
#                |            |  |  |
$B->test_method( ok        => 1, 0, sub { require Test::More; goto &Test::More::ok } );
$B->test_method( nok       => 1, 0, sub { require Test::More; unshift @_, !shift; goto &Test::More::ok } );
$B->test_method( is        => 1, 1, sub { require Test::More; goto &Test::More::is } );
$B->test_method( isnt      => 1, 1, sub { require Test::More; goto &Test::More::isnt } );
$B->test_method( like      => 1, 1, sub { require Test::More; goto &Test::More::like } );
$B->test_method( unlike    => 1, 1, sub { require Test::More; goto &Test::More::unlike } );
$B->test_method( is_deeply => 0, 1, sub { require Test::More; goto &Test::More::is_deeply } );

# Extra convenience test method:
sub quiet {
  my $self = shift;
  my ($name) = @_;
  my @fail;
  for my $m (qw/stdout stderr/) {
    my $buf = $self->$m . ''; # coerce to string
    push @fail, "Expecting no \U$m\E, but got " . dump($buf) if $buf ne '';
  }
  my $Test = Test::More->builder;
  my $ok = $Test->ok(!@fail, $name);
  $Test->diag(join"\n", @fail) unless $ok;
  $ok;
}

1; # End of Test::Trap

__END__

=head1 NAME

Test::Trap - Trap exit codes, exceptions, output, etc.

=head1 VERSION

Version 0.0.20

=head1 SYNOPSIS

  use Test::More;
  use Test::Trap qw( trap $trap );

  my @r = trap { some_code(@some_parameters) };
  is ( $trap->exit, 1, 'Expecting &some_code to exit with 1' );
  is ( $trap->stdout, '', 'Expecting no STDOUT' );
  like ( $trap->stderr, qr/^Bad parameters; exiting\b/, 'Expecting warnings.' );

=head1 DESCRIPTION

Primarily (but not exclusively) for use in test scripts: A block eval
on steroids, configurable and extensible, but by default trapping
(Perl) STDOUT, STDERR, warnings, exceptions, would-be exit codes, and
return values from boxed blocks of test code.

The values collected by the latest trap can then be queried or tested
through a a special result object.

=head1 EXPORT

A function and a scalar may be exported by any name.  The function (by
default named C<trap>) is an analogue to block eval(), and the scalar
(by default named C<$trap>) is the corresponding analogue to B<$@>.

Optionally, you may specify the default layers for the exported trap.
Layers may be specified by name, with a colon sigil.  Multiple layers
may be given in a list, or just stringed together like
C<:flow:stderr:warn>.

(For the advanced user, you may also specify anonymous layer
implementations -- i.e. an appropriate subroutine.)

See below for a list of the built-in layers, all of which are enabled
by default.  Note, finally, that the ordering of the layers matter:
The :raw layer is always on the bottom (anything underneath it is
ignored), and any other "flow control" layers used should be right
down there with it.

=head1 FUNCTION

=head2 trap BLOCK

This function may be exported by any name, but defaults to C<trap>.

Traps exceptions like block eval, but (by default) also traps exits
and exit codes, returns and return values, context, and (Perl) STDOUT,
STDERR, and warnings, All information trapped can be queried by way of
the status object, which is by default exported as C<$trap>, but can
be exported by any name.

=head1 TRAP LAYERS

It is possible to register more (see L<Test::Trap::Builder>), but the
following layers are pre-defined by this module:

=head2 :raw

The terminating layer, at which the processing of the layers stops,
and the actual call to the user code is performed.  On success, it
collects the return value(s) in the appropriate context.  Pushing the
:raw layer on a trap will for most purposes remove all layers below.

=head2 :die

The layer emulating block eval, capturing normal exceptions.

=head2 :exit

The third "flow control" layer, capturing exit codes if anything used
in the dynamic scope of the trap calls CORE::GLOBAL::exit().  (See
CAVEATS below for more.)

=head2 :flow

A pseudo-layer shortcut for :raw:die:exit.  Since this includes :raw,
pushing :flow on a trap will remove all layers below.

=head2 :stdout, :stderr

Layers trapping Perl output on STDOUT and STDERR, respectively.

=head2 :stdout(perlio), :stderr(perlio)

As above, but specifying a backend implemented using PerlIO::scalar.
If this backend is not availible (typically if PerlIO is not), this is
an error.

=head2 :stdout(tempfile), :stderr(tempfile)

As above, but specifying a backend implemented using File::Temp.  Note
that this is the default implementation, whenever it is availible, so
the only effect of specifying it, is that if it is not availible, it
will fail, rather than fall back on another implementation.

=head2 :stdout(a;b;c), :stderr(a,b,c)

(Either syntax, commas or semicolons, is permitted, as is any number
of names in the list.)  As above, but specifying the backend
implementation by the first existing name among I<a>, I<b>, and I<c>.
If no such implementation is availible, this is an error.

=head2 :warn

A layer trapping warnings, with additionally tee: If STDERR is open,
it will also print the warnings there.  (This output may be trapped by
the :stderr layer, be it above or below the :warn layer.)

=head2 :default

A pseudo-layer short-cut for :raw:die:exit:stdout:stderr:warn.  Since
this includes :raw, pushing :default on a trap will remove all layers
below.  The other interesting property of :default is that it is what
every trap starts with:  In order not to include any of the six layers
that make up :default, you need to push a terminating layer (such as
:raw or :flow) on the trap.

=head1 RESULT ACCESSORS

The following methods may be called on the result objects after any
trap has been sprung, and access the cooked results of the run.

Any property will be undef if not actually trapped -- whether because
there is no layer to trap them or because flow control passed them by.
(If there is an active and successful trap layer, empty strings and
empty arrays trapped will of course be defined.)

=head2 leaveby

Returns a string indicating how the trap terminated: C<return>,
C<die>, or C<exit>.

=head2 die

Returns the exception, if the latest trap threw one.

=head2 exit

Returns the exit code, if the latest trap tried to exit.

=head2 return

Returns an arrayref of return values, if the latest trap returned.

=head2 stdout, stderr

Returns the captured output on the respective file handles.

=head2 warn

Returns an arrayref of warnings from the latest trap.

=head2 wantarray

Returns the context in which the latest trap was called.

=head2 list, scalar, void

True if the latest trap was called in the indicated context.

=head1 RESULT TESTS

For each accessor, a number of convenient standard test methods are
also availible.  By default, these are a few standard tests from
Test::More, plus the C<nok> test, being a negated C<ok> test.  All for
convenience:

=head2 I<ACCESSOR>_ok        [INDEX,] TEST_NAME

=head2 I<ACCESSOR>_nok       [INDEX,] TEST_NAME

=head2 I<ACCESSOR>_is        [INDEX,] SCALAR, TEST_NAME

=head2 I<ACCESSOR>_isnt      [INDEX,] SCALAR, TEST_NAME

=head2 I<ACCESSOR>_like      [INDEX,] REGEX, TEST_NAME

=head2 I<ACCESSOR>_unlike    [INDEX,] REGEX, TEST_NAME

=head2 I<ACCESSOR>_is_deeply          STRUCTURE, TEST_NAME

I<INDEX> is not optional:  It is required for array accessors (like
C<return> and C<warn>), and disallowed for scalar accessors.  Note
that the C<is_deeply> test does not accept an index.  Even for array
accessors, it operates on the entire array.

For convenience, again, a flow control I<ACCESSOR> (C<return>, C<die>,
C<exit>) will first test whether the trap was left by way of the flow
control mechanism in question.

=head2 did_die, did_exit, did_return

Conveniences: Tests whether the trap was left by way of the flow
control mechanism in question.  Much like C<leaveby_is('die')> etc,
but with better diagnostics.

=head2 quiet

Convenience: Passes if zero-length output was trapped on both STDOUT
and STDERR, and generate better diagnostics otherwise.

=head1 CAVEATS

This module must be loaded before any code containing exit()s to be
trapped is compiled.  Any exit() already compiled won't be trappable,
and will terminate the program anyway.

This module overrides &CORE::GLOBAL::exit, so may not work correctly
(or even at all) in the presence of other code overriding
&CORE::GLOBAL::exit.  More precisely: This module installs its own
exit() on entry of the block, and restores the previous one, if any,
only upon leaving the block.

If you use fork() in the dynamic scope of a trap, beware that the
(default) :exit layer of that trap does not trap exit() in the
children, but passes them to the outer handler.  If you think about
it, this is what you are likely to want it to do in most cases.

Note that the (default) :exit layer only traps &CORE::GLOBAL::exit
calls (and bare exit() calls that compile to that).  It makes no
attempt to trap CORE::exit(), POSIX::_exit(), exec(), nor segfault.
Nor does it attempt to trap anything else that might terminate the
program.  The trap is a block eval on steroids -- not the last block
eval of Krypton!

This module traps warnings using C<$SIG{__WARN__}>, so may not work
correctly (or even at all) in the presence of other code setting this
handler.  More precisely: This module installs its own __WARN__
handler on entry of the block, and restores the previous one, if any,
only upon leaving the block.

The (default) :stdout and :stderr handlers will not trap output from
system() calls.

Threads?  No idea.  It might even work correctly.

=head1 BUGS

On Windows, fork() within a trap appears to crash perl.  (This is a
TODO:  I'm not sure if this can be remedied, but the least we can do
is fail more nicely.)

Please report any bugs or feature requests directly to the author.

=head1 AUTHOR

Eirik Berg Hanssen, C<< <ebhanssen@allverden.no> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Eirik Berg Hanssen, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

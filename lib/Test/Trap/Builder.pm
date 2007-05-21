package Test::Trap::Builder;

use version; $VERSION = qv('0.0.8');

use strict;
use warnings;
use Data::Dump qw(dump);
use Carp qw(croak);
our (@CARP_NOT, @ISA);
use Exporter ();
BEGIN {
  *import = \&Exporter::import;
  my @methods = qw( Next Exception Teardown Run TestAccessor );
  our @EXPORT_OK = (@methods);
  our %EXPORT_TAGS = ( methods => \@methods );
}
use constant GOT_CARP_NOT => $] >= 5.008;

# Methods on the result object:

sub Next {
  my $next = pop @{$_[0]{_layers}};
  goto &$next;
}

sub Exception {
  my $self = shift;
  push @{$self->{_exception}}, @_;
  local *@;
  eval { $self->{__exception}->() };
  # XXX: PANIC!  We returned!?!
  CORE::exit(8); # XXX: Is there a more approprate exit value?
}

sub Teardown {
  my $self = shift;
  push @{$self->{_teardown}}, @_;
}

sub Run {
  my $self = shift;
  my $code = $self->{_code};
  goto &$code;
}

sub TestAccessor {
  my $self = shift;
  return $self->{_test_accessor};
}

# Utiliy functions and methods on the builder class/object:

sub _carpnot_for ($) {
  my $pkg = shift;
  return if $pkg eq __PACKAGE__;
  return $pkg;
}

my $builder = bless
  { test => {},
    accessor => {},
    output_layer_backend => {},
  };

sub new { $builder }

sub trap {
  my $this = shift;
  my ($module, $glob, $layers, $code) = @_;
  my $current = bless
    { wantarray   => (my $wantarray = wantarray),
    }, $module;
TEST_TRAP_BUILDER_INTERNAL_EXCEPTION: {
    local *@;
    local @{$current}{qw( _code _layers _teardown _exceptions __exception )}
      = ( $code, [@$layers], [], [],
	  sub {
	    no warnings 'exiting';
	    last TEST_TRAP_BUILDER_INTERNAL_EXCEPTION;
	  },
	);
    eval { $current->Next };
    eval { $_->() } for reverse @{$current->{_teardown}};
    undef @{$current->{_teardown}};
    ${*$glob} = $current;
    my $return = $current->{return} || [];
    return $wantarray ? @$return : $return->[0];
  }
  local $Carp::CarpLevel = 1; # skip the real trap{} implementation
  croak join"\n", @{$current->{_exception}};
}

sub _layer {
  my ($pkg, $name, $sub) = @_;
  no strict 'refs';
  *{"$pkg\::layer:$name"} = $sub;
}

sub layer {
  my $this = shift;
  my ($name, $sub) = @_;
  _layer(scalar caller, $name, sub { $sub });
}

sub multi_layer {
  my $this = shift;
  my $name = shift;
  my $callpkg = caller;
  my @layer = $builder->layer_implementation($callpkg, @_);
  _layer(scalar caller, $name, sub { @layer });
}

sub output_layer {
  my $this = shift;
  my ($name, $globref) = @_;
  my $code = sub {
    my $class = shift;
    my ($arg) = @_;
    my $implementation;
  IMPLEMENTATION: {
      my @backends = defined($arg) ?
	split /[,;]/, $arg : eval { my $m = 'backend:output'; $class->$m }
	  or croak "No default backend and none specified for :$name";
      for my $backend (@backends) {
	$implementation = $builder->{output_layer_backend}{$backend}
	  and last IMPLEMENTATION;
      }
      croak "No output layer implementation found for " . dump(@backends);
    }
    return sub {
      my $self = shift;
      $self->{$name} = '';
      my $fileno;
      # common stuff:
      unless (tied *$globref or defined($fileno = fileno *$globref)) {
	return $self->Next;
      }
      $self->$implementation($name, $fileno, $globref);
    };
  };
  _layer(scalar caller, $name, $code);
}

sub output_layer_backend {
  my $this = shift;
  my ($name, $backend) = @_;
  my $h = $builder->{output_layer_backend};
  $h->{$name} = $backend;
}

sub default_output_layer_backends {
  my $this = shift;
  my @backends = @_;
  my $trapper = caller;
  no strict 'refs';
  *{"$trapper\::backend:output"} = sub { @backends };
}

sub layer_implementation {
  my $this = shift;
  # Directly calling layer_implementation, we should know what we're doing:
  local( GOT_CARP_NOT ? @CARP_NOT : @ISA ) = _carpnot_for caller;
  my $trapper = shift;
  my @r;
  for (@_) {
    if ( length ref and eval { exists &$_ } ) {
      push @r, $_;
      next;
    }
    my ($name, $arg) =
      /^ ( [^\(]+ )      # meth: anything but '('
         (?:             # begin optional group
             \(          # literal '('
             ( [^\)]* )  # arg: anything but ')'
             \)          # literal ')'
         )?              # end optional group
      \z/x;
    my $meth = "layer:$name";
    $trapper->can($meth) or croak qq[Unknown trapper layer "$_"];
    push @r, $trapper->$meth($arg);
  }
  return @r;
}

BEGIN {
  # state for the closures in %argspec -- obviously not reentrant:
  my ($object, @param);
  my ($accessor, $indexed, $index);
  my %argspec =
    ( object    => sub { $object },
      indexed   => sub { $object->$accessor( $indexed ? $index = shift(@param) : () ) },
      all       => sub { $object->$accessor },
      predicate => sub { shift @param },
      name      => sub { shift @param },
    );

  sub _accessor_test {
    my ($mpkg, $mname, $adef, $tdef) = @_;
    my ($targs, $tcode) = @$tdef;
    my $acode = $adef->{code};
    my $use_index = $adef->{is_array} && grep {$_ eq 'indexed'} @$targs;
    my $test_name_index = 0;
    for (@$targs) {
      last if /name/;
      $test_name_index++ if /predicate/ or (/indexed/ and $use_index);
    }
    my $basic = sub {
      # set up the state:
      ($object, @param) = @_;
      ($accessor, $indexed, $index) = ($acode, $use_index, '');
      my @args = map {$argspec{$_}->()} @$targs;
      my $self = shift;
      local $self->{_test_accessor} = "$adef->{name}($index)";
      local $Test::Builder::Level = $Test::Builder::Level+1;
      $tcode->(@args);
    };
    my $wrong_leaveby = sub {
      my $self = shift;
      my $Test = Test::More->builder;
      my $ok = $Test->ok('', $_[$test_name_index]);
      my $got = $self->leaveby;
      $Test->diag(sprintf<<DIAGNOSTIC, $adef->{name}, $got, dump($self->$got));
    Expecting to %s(), but instead %s()ed with %s
DIAGNOSTIC
      return $ok;
    };
    no strict 'refs';
    if ($adef->{is_leaveby}) {
      return *{"$mpkg\::$mname"} = sub {
	goto &{ ($_[0]->leaveby eq $adef->{name}) ? $basic : $wrong_leaveby };
      };
    }
    else {
      return *{"$mpkg\::$mname"} = $basic;
    }
  }

  sub test {
    my $this = shift;
    my ($tname, $targs, $code) = @_;
    my $tpkg = caller;
    my @targs = $targs =~ /(\w+)/g;
    for (@targs) {
      next if exists $argspec{$_};
      croak "Unrecognized identifier $_ in argspec";
    }
    my $tdef = $builder->{test}{$tpkg}{$tname} = [ \@targs, $code ];
    # make the test methods:
    for my $apkg (keys %{$builder->{accessor}}) {
      my $mpkg = $apkg->isa($tpkg) ? $apkg
               : $tpkg->isa($apkg) ? $tpkg
	       : next;
      for my $aname (keys %{$builder->{accessor}{$apkg}}) {
	my $adef = $builder->{accessor}{$apkg}{$aname};
	_accessor_test($mpkg, "$aname\_$tname", $adef, $tdef);
      }
    }
  }
}

sub _accessor {
  my ($apkg, $aname, $par, $code) = @_;
  no strict 'refs';
  *{"$apkg\::$aname"} = $code;
  my $adef = $builder->{accessor}{$apkg}{$aname} = { %$par, code => $code, name => $aname };
  # make the test methods:
  my $tdef = [ ['name'], \&Test::More::pass ];
  _accessor_test($apkg, "did_$aname", $adef, $tdef);
  for my $tpkg (keys %{$builder->{test}}) {
    my $mpkg = $apkg->isa($tpkg) ? $apkg
             : $tpkg->isa($apkg) ? $tpkg
	     : next;
    for my $tname (keys %{$builder->{test}{$tpkg}}) {
      my $tdef = $builder->{test}{$tpkg}{$tname};
      _accessor_test($mpkg, "$aname\_$tname", $adef, $tdef);
    }
  }
}

sub _scalar_accessor {
  my $name = shift;
  return sub { $_[0]{$name} };
}

sub _array_accessor {
  my $name = shift;
  return sub {
    my $self = shift;
    return   $self->{$name}      unless @_;
    return @{$self->{$name}}[@_] if wantarray;
    return   $self->{$name}[shift];
  };
}

sub accessor {
  my $this = shift;
  my %par = @_;
  my $simple = delete $par{simple};
  my $flexible = delete $par{flexible};
  my $pkg = caller;
  for my $name (keys %{$flexible||{}}) {
    _accessor($pkg, $name, \%par, $flexible->{$name});
  }
  my $factory = $par{is_array} ? \&_array_accessor : \&_scalar_accessor;
  for my $name (@{$simple||[]}) {
    _accessor($pkg, $name, \%par, $factory->($name));
  }
}

1; # End of Test::Trap::Builder

__END__

=head1 NAME

Test::Trap::Builder - Backend for building test traps

=head1 VERSION

Version 0.0.8

=head1 SYNOPSIS

  package My::Test::Trap;

  use Test::Trap::Builder;
  my $B = Test::Trap::Builder->new;

  $B->layer( $layer_name => \&layer_implementation );
  $B->accessor( simple => [ $layer_name ] );

  $B->multi_layer( $multi_name => @names );

  $B->test_method( $test_name => 0, $name_index, \&test_function );

=head1 DESCRIPTION

Test::Trap's standard trap layers don't trap everything you might want
to trap.  So, Test::Trap::Builder provides methods to write your own
trap layers -- preferrably for use with your own test trap module.

Note that layers are methods with mangled names (names are prefixed
with C<layer:>), and so inherited like any other method.

=head1 EXPORTS

Test trap modules should not inherit from Test::Trap::Builder, but may
import a few convenience methods for use in layer implementations.
Layers should be implemented as methods, and while they need not call
these convenience methods in turn, that likely makes for more readable
code than any alternative.

Do not use them as methods of Test::Trap::Builder -- they are intended
to be methods of test trap objects, and won't work otherwise.  In
fact, they should probably not be called outside of layer
implementations.

=head2 Run

A terminating layer may call this method to run the user code.

=head2 Next

Every non-terminating layer should call this method (or an equivalent)
to progress to the next layer.  Note that this method need not return,
so any teardown actions should probably be registered with the
Teardown method (see below).

=head2 Teardown SUBS

If your layer wants to clean up its setup, it may use this method to
register any number of teardown actions, to be performed (in reverse
registration order) once the user code has been executed.

=head2 Exception STRINGS

Layer implementations may run into exceptional situations, in which
they want the entire trap to fail.  Unfortunately, another layer may
be trapping ordinary exceptions, so you need some kind of magic in
order to throw an untrappable exception.  This is one convenient way.

Note: The Exception method won't work if called from outside of the
regular control flow, like inside a DESTROY method or signal handler.
If anything like this happens, CORE::exit will be called with an exit
code of 8.

=head2 TestAccessor

Returns the name with index (if any) of the accessor for which the
current test implementation is called.

=head1 METHODS

=head2 new

Returns a singleton object.  Don't expect this module to work with
a different object of this class.

=head2 trap MODULE, GLOBREF, LAYERARRAYREF, CODE

Implements a trap for I<MODULE>, using the scalar slot of I<GLOBREF>
for the result object, applying the layers of I<LAYERARRAYREF>,
trapping results of the user I<CODE>.

In most cases, the test trap module may conveniently export a function
calling this method.

=head2 layer NAME, CODE

Makes a layer I<NAME> implemented by I<CODE>.  It should expect to be
invoked on the result object being built, with no arguments, and
should call either the Next() or Run() method or equivalent.

=head2 output_layer NAME, GLOBREF

Makes a layer I<NAME> for trapping output on the file handle of the
I<GLOBREF>, using I<NAME> also as the attribute name.

=head2 output_layer_backend NAME, CODE

Registers, by I<NAME>, a I<CODE> implementing an output trap layer
backend.  The I<CODE> will be called on the result object, with the
layer name and the output handle's fileno and globref as parameters.

=head2 default_output_layer_backends NAMES

For the calling trapper package and those that inherit from it, the
first found among the output layer backends named by I<NAMES> will be
used when no backend is specified.

=head2 multi_layer NAME, LAYERS

Makes a layer I<NAME> that just pushes a number of other I<LAYERS> on
the queue of layers.  If any of the I<LAYERS> is neither an anonymous
method nor the name of a layer known to the caller, an exception is
raised.

=head2 layer_implementation PACKAGE, LAYERS

Returns the subroutines that implement the requested I<LAYERS>.  If
any of the I<LAYERS> is neither an anonymous method nor the name of a
layer known to the I<PACKAGE>, an exception is raised.

=head2 test NAME, ARGSPEC, CODE

Registers a test method template for the calling trapper package.
Test methods of the form I<ACCESSOR>_I<NAME> will be generated in the
proper (i.e. inheriting) package for every registered I<ACCESSOR> of a
package that either inherits or is inherited by the calling package.
To perform the test, the implicit leaveby condition will be tested,
before the I<CODE> eventually is called with arguments according to
the words found in the I<ARGSPEC> string:

=over

=item object

The result object.

=item all

The I<ACCESSOR>'s return value when called without argements.

=item indexed

An array I<ACCESSOR>'s return value when called with proper index
(taken from the test method's parameters); a scalar I<ACCESSOR>'s
return value when called without arguments.

=item predicate

What the I<ACCESSOR>'s return value should be tested against (taken
from the test method's parameters).  (There may be more than one
predicate.)

=item name

The test name.

=back

=head2 accessor NAMED_PARAMS

Generates and registers any number of accessors according to the
I<NAMED_PARAMS>.  Will also make the proper test methods for these
accessors (see above).  The following parameters are recognized:

=over

=item is_leaveby

If true, the tests methods will generate better diagnostics if the
trap was not left as specified.  Also, a special did_I<ACCESSOR> test
method will be generated (unless already present), simply passing as
long as the trap was left as specified.

=item is_array

If true, the simple accessor(s) will be smart about context and
parameters, returning an arrayref on no parameter, an array slice in
list context, and the element indexed by the first parameters
otherwise.

=item simple

Should be a reference to an array of accessor names.  For each name,
an accessor, simply looking up by the name in the result object, will
be generated and registered,

=item flexible

Should be a reference to a hash.  For each pair, a name and an
implementation, an accessord is generated and registered.

=back

=head1 EXAMPLE

A complete example, implementing a I<timeout> layer (depending on
Time::HiRes::ualarm being present), a I<simpletee> layer (printing the
trapped stdout/stderr to the original file handles after the trap has
sprung), and a I<cmp_ok> test method template:

  package My::Test::Trap;
  use base 'Test::Trap'; # for example
  use Test::Trap::Builder;

  my $B = Test::Trap::Builder->new;

  # example (layer:timeout):
  use Time::HiRes qw/ualarm/;
  $B->layer( timeout => $_ ) for sub {
    my $self = shift;
    eval {
      local $SIG{ALRM} = sub {
	$self->{timeout} = 1; # simple truth
	$SIG{ALRM} = sub {die};
	die;
      };
      ualarm 1000, 1; # one second max, then die repeatedly!
      $self->Next;
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
    my $self = shift;
    for (qw/ stdout stderr /) {
      next unless exists $self->{$_};
      die "Too late to tee $_";
    }
    $self->Teardown($_) for sub {
      print STDOUT $self->{stdout} if exists $self->{stdout};
      print STDERR $self->{stderr} if exists $self->{stderr};
    };
    $self->Next;
  };
  # no accessor for this layer

  $B->multi_layer( flow => qw/ raw die exit timeout / );
  $B->multi_layer( default => qw/ flow stdout stderr warn simpletee / );

  $B->test_method( cmp_ok => 1, 2, \&Test::More::cmp_ok );

=head1 CAVEATS

The interface of this module is likely to remain somewhat in flux for
a while yet.

The different implementations of output trap layers have their own
caveats; see L<Test::Trap::Builder::Tempfile>,
L<Test::Trap::Builder::PerlIO>, L<Test::Trap::Builder::SystemSafe>.

Diamond inheritence is not (yet?) fully supported.  If one parent has
registered a test method template C<X> and another has registered an
accessor C<Y>, the test method C<Y_X> will not be generated.

Threads?  No idea.  It might even work correctly.

=head1 BUGS

Please report any bugs or feature requests directly to the author.

=head1 AUTHOR

Eirik Berg Hanssen, C<< <ebhanssen@allverden.no> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006-2007 Eirik Berg Hanssen, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

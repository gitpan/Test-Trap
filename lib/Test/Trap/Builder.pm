package Test::Trap::Builder;

use version; $VERSION = qv('0.0.5');

use strict;
use warnings;
use Data::Dump qw(dump);
use Carp qw(croak);
our (@CARP_NOT, @ISA);
use constant GOT_CARP_NOT => $] >= 5.008;

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
      my $self = shift; my $next = pop;
      my $is_open = defined fileno *$globref;
      local *$globref;
      $self->{$name} = '';
      my $scoper = $is_open && $implementation->($self, $name, $globref);
      $self->$next(@_);
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
    if (UNIVERSAL::isa($_, 'CODE')) {
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

sub _accessor_test {
  my ($mpkg, $mname, $adef, $tdef) = @_;
  my ($is_indexing, $test_name_index, $tcode) = @$tdef;
  my $acode = $adef->{code};
  my $use_index = $is_indexing && $adef->{is_array};
  my $basic = sub {
    my $self = shift;
    my $got = $self->$acode( $use_index ? shift : () );
    local $Test::Builder::Level = $Test::Builder::Level+1;
    $tcode->( $got, @_ );
  };
  no strict 'refs';
  unless ($adef->{is_leaveby}) {
    return *{"$mpkg\::$mname"} = $basic;
  }
  *{"$mpkg\::$mname"} = sub {
    my $got = $_[0]->leaveby;
    goto &$basic if $got eq $adef->{name};
    my $self = shift;
    my $Test = Test::More->builder;
    shift if $use_index;
    my $ok = $Test->ok('', $_[$test_name_index]);
    $Test->diag(sprintf<<DIAGNOSTIC, $adef->{name}, $got, dump($self->$got));
    Expecting to %s(), but instead %s()ed with %s
DIAGNOSTIC
    $ok;
  };
}

sub test_method {
  my $this = shift;
  my ($tname, $is_indexing, $test_name_index, $code) = @_;
  my $tpkg = caller;
  my $tdef = $builder->{test}{$tpkg}{$tname} = [ $is_indexing, $test_name_index, $code ];
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

sub _accessor {
  my ($apkg, $aname, $par, $code) = @_;
  no strict 'refs';
  *{"$apkg\::$aname"} = $code;
  my $adef = $builder->{accessor}{$apkg}{$aname} = { %$par, code => $code, name => $aname };
  # make the test methods:
  my $tdef = [ 0, 0, sub { shift; goto &Test::More::pass } ];
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
    my $f = shift;
    return   $self->{$name}[$f];
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

Version 0.0.5

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

=head1 METHODS

=head2 new

Returns a singleton object.  Don't expect this module to work with
a different object of this class.

=head2 layer NAME, CODE

Makes a layer I<NAME> implemented by I<CODE>.  Unless it is a
terminating or otherwise special layer, the implementation should
expect the result object as the first argument and the next layer as
the final argument.

=head2 output_layer NAME, GLOBREF

Makes a layer I<NAME> for trapping output on the file handle of the
I<GLOBREF>, using I<NAME> also as the attribute name.

=head2 output_layer_backend NAME, CODE

Registers, by I<NAME>, a I<CODE> implementing an output trap layer
backend.  The I<CODE> will be called with the result object, the
(layer) name, and the output handle's globref as parameters.  It may
return an object, which then will be kept alive until after the call
to lower levels (that is to say, DESTROY methods may be useful -- see
the L<Test::Trap::Builder::TempFile> implementation).

=head2 default_output_layer_backends NAMES

For the calling trapper package and those that inherit from it, the
first found among the output layer backends named by I<NAMES> will be
used when no backend is specified.

=head2 multi_layer NAME, LAYERS

Makes a layer I<NAME> that just pushes a number of other I<LAYERS> on
the queue of layers.  If any of the I<LAYERS> is neither an anonymous
method nor the name of a layer known to the caller, an exception is
raised.

=head2 layer_implementation PAKCAGE, LAYERS

Returns the subroutines that implement the requested I<LAYERS>.  If
any of the I<LAYERS> is neither an anonymous method nor the name of a
layer known to the I<PACKAGE>, an exception is raised.

=head2 test_method NAME, IS_INDEXING, TEST_NAME_INDEX, CODE

Registers a test method template I<NAME> for the calling trapper
package.  Makes test methods of the form I<ACCESSOR>_I<NAME> in the
proper (i.e. inheriting) package for every registered I<ACCESSOR> of a
package that either inherits or is inherited by the calling package.

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

A cmoplete example, implementing a I<timeout> layer (depending on
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

=head1 CAVEATS

The interface of this module is likely to remain somewhat in flux for
a while yet.

If File::Temp is not availible, the layers generated by output_layer()
use in-memory files, and so will not (indeed cannot) trap output from
forked-off processes -- including system() calls.

Even if File::Temp is availible, the file descriptors aren't right, so
you won't in general be able to trap output from exec'ed commands --
including system() calls.

Threads?  No idea.  It might even work correctly.

=head1 BUGS

Please report any bugs or feature requests directly to the author.

=head1 AUTHOR

Eirik Berg Hanssen, C<< <ebhanssen@allverden.no> >>

=head1 COPYRIGHT & LICENSE

Copyright 2006 Eirik Berg Hanssen, All Rights Reserved.

This program is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

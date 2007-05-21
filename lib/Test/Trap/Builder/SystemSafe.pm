package Test::Trap::Builder::SystemSafe;

use version; $VERSION = qv('0.0.6');

use strict;
use warnings;
use Test::Trap::Builder;
use File::Temp qw( tempfile );

sub import {
  my $builder = Test::Trap::Builder->new;
  $builder->output_layer_backend( systemsafe => $_ ) for sub {
    my $self = shift;
    my ($name, $fileno, $globref) = @_;
    my $pid = $$;
    if (tied *$globref or $fileno < 0) {
      $self->Exception("SystemSafe only works with real file descriptors; aborting");
    }
    my ($fh, $file) = tempfile; # XXX: Test?
    binmode $fh; # superfluos?
    open my $fh_keeper, ">&$fileno"
      or $self->Exception("Cannot dup '$fileno' for $name: '$!'");
    my $autoflush_keeper = $globref->autoflush;
    _close_reopen($self, $globref, $fileno, ">>$file",
		  sub {
		    sprintf "Cannot open %s for %s: '%s'",
		      $file, $name, $!;
		  },
		 );
    binmode *$globref; # must write with the same mode as we read.
    $globref->autoflush(1);
    $globref->print("Work around a strange buffering(?) bug.\n");
    $self->Teardown($_) for sub {
      if ($pid == $$) {
	# this process opened it, so it gets to collect the contents:
	local $/ = "\n";
	$fh->getline;
	undef $/;
	my $s = $fh->getline;
	$self->{$name} .= $s if defined $s;
	close $fh; # don't leak this one either!
      }
      # close and reopen the file to the keeper!
      my $fno = fileno $fh_keeper;
      _close_reopen($self, $globref, $fileno, ">&$fno",
		    sub {
		      sprintf "Cannot dup '%s' for %s: '%s'",
			fileno $fh_keeper, $name, $!;
		    },
		   );
      close $fh_keeper; # another potential leak, I suppose.
      $globref->autoflush($autoflush_keeper);
    };
    $self->Next;
  };
}

sub _close_reopen {
  my ($result, $glob, $fno_want, $what, $err) = @_;
  close *$glob;
  my @fh;
  while (1) {
    no warnings 'io';
    open *$glob, $what or $result->Exception($err->());
    my $fileno = fileno *$glob;
    last if $fileno == $fno_want;
    close *$glob;
    if ($fileno > $fno_want) {
      $result->Exception("Cannot get the desired descriptor, '$fno_want' (could it be that it is fdopened and so still open?)");
    }
    if (grep{$fileno == fileno($_)}@fh) {
      $result->Exception("Getting several files opened on fileno $fileno");
    }
    open my $fh, $what or $result->Exception($err->());
    if (fileno($fh) != $fileno) {
      $result->Exception("Getting fileno " . fileno($fh) . "; expecting $fileno");
    }
    push @fh, $fh;
  }
  close $_ for @fh;
}

1; # End of Test::Trap::Builder::SystemSafe

__END__

=head1 NAME

Test::Trap::Builder::SystemSafe - "Safe" output layer backend using File::Temp

=head1 VERSION

Version 0.0.6

=head1 DESCRIPTION

This module provides an implementation I<systemsafe>, based on
File::Temp, for the trap's output layers.  This implementation insists
on reopening the output file handles with the same descriptors, and
therefore, unlike L<Test::Trap::Builder::TempFile> and
L<Test::Trap::Builder::PerlIO>, is able to trap output from forked-off
processes, including system().

See also L<Test::Trap> (:stdout and :stderr) and
L<Test::Trap::Builder> (output_layer).

=head1 CAVEATS

Using File::Temp, we need privileges to create tempfiles.

We need disk space for the output of every trap (it should clean up
after the trap is sprung).

Disk access may be slow -- certainly compared to the in-memory files
of PerlIO.

If the file handle we try to trap using this backend is on an
in-memory file, it would not be availible to other processes in any
case.  Rather than change the semantics of the trapped code or
silently fail to trap output from forked-off processes, we just raise
an exception in this case.

If there is another file handle with the same descriptor (f ex after
an C<< open OTHER, '>&=', THIS >>), we can't get that file descriptor.
Rather than silently fail, we again raise an exception.

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
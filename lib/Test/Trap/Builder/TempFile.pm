package Test::Trap::Builder::TempFile;

use version; $VERSION = qv('0.0.1');

use strict;
use warnings;
use Test::Trap::Builder;
use File::Temp qw( tempfile );

sub import {
  my $builder = Test::Trap::Builder->new;

  $builder->output_layer_backend( tempfile => $_ ) for sub {
    my ($result, $name, $globref) = @_;
    my $scoper = bless { result => $result, name => $name, pid => $$ };
    @{$scoper}{qw/fh file/} = tempfile;
    no warnings 'io';
    open *$globref, '>>', $scoper->{file};
    $globref->autoflush(1);
    return $scoper;
  };
}

sub DESTROY {
  my $self = shift;
  my ($result, $name, $fh, $file, $pid) = @{$self}{qw/ result name fh file pid/};
  # if the file is opened by some other process, that one should deal with it:
  return unless $pid == $$;
  local $/;
  $result->{$name} .= <$fh>;
}

1; # End of Test::Trap::Builder::TempFile

__END__

=head1 NAME

Test::Trap::Builder::TempFile - Output layer backend using File::Temp

=head1 VERSION

Version 0.0.1

=head1 DESCRIPTION

This module provides an implementation I<tempfile>, based on
File::Temp, for any output layer on the trap -- see L<Test::Trap>
(:stdout and :stderr) and L<Test::Trap::Builder> (output_layer).

=head1 CAVEATS

Using File::Temp, we need privileges to create tempfiles.

We need disk space for the output of every trap (it should clean up
after the trap is sprung).

Disk access may be slow -- certainly compared to the in-memory files
of PerlIO.

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

package Cwd::utf8;
use strict;
use warnings;
use 5.010; # state

# ABSTRACT: Fully UTF-8 aware Cwd
# VERSION

=head1 SYNOPSIS

=for test_synopsis
my $file;

    # Using the utf-8 versions of cwd, getcwd, fastcwd, fastgetcwd
    use Cwd::utf8;
    my $dir = getcwd;

    # Using the utf-8 versions of abs_path
    use Cwd::utf8 qw(abs_path);
    my $abs_path = abs_path($file);

    # Exporting no functions
    use Cwd::utf8 qw(:none); # NOT "use Cwd::utf8 qw();"!
    my $real_path = Cwd::real_path($file);

=head1 DESCRIPTION

While the original L<Cwd> functions are capable of handling UTF-8
quite well, they expects and return all data as bytes, not as
characters.

This module replaces all the L<Cwd> functions with fully UTF-8 aware
versions, both expecting and returning characters.

B<Note:> Replacement of functions is not done on DOS, Windows, and OS/2
as these systems do not have full UTF-8 file system support.

=head2 Behaviour

The module behaves as a pragma so you can use both C<use
Cwd::utf8> and C<no Cwd::utf8> to turn utf-8 support on
or off.

By default, cwd(), getcwd(), fastcwd(), and fastgetcwd() (and, on
Win32, getdcwd()) are exported (as with the original L<Cwd>). If you
want to prevent this, use C<use Cwd::utf8 qw(:none)>. (As all the
magic happens in the module's import function, you can not simply use
C<use Cwd::utf8 qw()>)

=head1 COMPATIBILITY

The filesystems of Dos, Windows, and OS/2 do not (fully) support
UTF-8. The L<Cwd> function will therefore not be replaced on these
systems.

=head1 SEE ALSO

=for :list
* L<Cwd> -- The original module
* L<File::Find::utf8> -- Fully utf-8 aware versions of the L<File::Find>
  functions.
* L<utf8::all> -- Turn on utf-8, all of it.
  This was also the module I first added the utf-8 aware versions of
  L<Cwd> and L<File::Find> to before moving them to their own package.

=cut

use Cwd ();
use Encode ();

# Holds the pointers to the original version of redefined functions
state %_orig_functions;

# Current (i.e., this) package
my $current_package = __PACKAGE__;

# Original package (i.e., the one for which this module is replacing the functions)
my $original_package = $current_package;
$original_package =~ s/::utf8$//;

require Carp;
$Carp::Internal{$current_package}++; # To get warnings reported at correct caller level

=attr $Cwd::utf8::UTF8_CHECK

By default C<Cwd:::utf8> marks decoding errors as fatal (default value
for this setting is C<Encode::FB_CROAK>). If you want, you can change this by
setting C<Cwd::utf8::UTF8_CHECK>. The value C<Encode::FB_WARN> reports
the encoding errors as warnings, and C<Encode::FB_DEFAULT> will completely
ignore them. Please see L<Encode> for details. Note: C<Encode::LEAVE_SRC> is
I<always> enforced.

=cut

our $UTF8_CHECK = Encode::FB_CROAK | Encode::LEAVE_SRC; # Die on encoding errors

# UTF-8 Encoding object
my $_UTF8 = Encode::find_encoding('UTF-8');

sub import {
    # Target package (i.e., the one loading this module)
    my $target_package = caller;

    # If run on the dos/os2/windows platform, ignore overriding functions silently.
    # These platforms do not have (proper) utf-8 file system suppport...
    unless ($^O =~ /MSWin32|cygwin|dos|os2/) {
        no strict qw(refs); ## no critic (TestingAndDebugging::ProhibitNoStrict)
        no warnings qw(redefine);

        # Redefine each of the functions to their UTF-8 equivalent
        for my $f (@{$original_package . '::EXPORT'}, @{$original_package . '::EXPORT_OK'}) {
            # If we already have the _orig_function, we have redefined the function
            # in an earlier load of this module, so we need not do it again
            unless ($_orig_functions{$f}) {
                $_orig_functions{$f} = \&{$original_package . '::' . $f};
                *{$original_package . '::' . $f} = sub { return _utf8_cwd($f, @_); };
            }
        }
        $^H{$current_package} = 1; # Set compiler hint that we should use the utf-8 version
    }

    # Determine symbols to export
    shift; # First argument contains the package (that's us)
    @_ = (':DEFAULT') if !@_; # If nothing provided, use default
    @_ = map { $_ eq ':none' ? () : $_ } @_; # Replace :none tag with empty list

    # Use exporter to export
    require Exporter;
    Exporter::export_to_level($original_package, 1, $target_package, @_) if (@_);

    return;
}

sub unimport { ## no critic (Subroutines::ProhibitBuiltinHomonyms)
    $^H{$current_package} = 0; # Set compiler hint that we should not use the utf-8 version
    return;
}

sub _utf8_cwd {
    my $func = shift;

    my $hints = (caller 1)[10]; # Use caller level 1 because of the added anonymous sub around call
    if (! $hints->{$current_package}) {
        # Use original function if we're not using Cwd::utf8 in calling package
        return $_orig_functions{$func}->(@_);
    } else {
        $UTF8_CHECK |= Encode::LEAVE_SRC if $UTF8_CHECK; # Enforce LEAVE_SRC
        my @args = map { $_ ? $_UTF8->encode($_, $UTF8_CHECK) : $_ } @_;
        if (wantarray) {
            return map { $_ ? $_UTF8->decode($_, $UTF8_CHECK) : $_ } $_orig_functions{$func}->(@args);
        } else {
            my $r = $_orig_functions{$func}->(@args);
            return $r ? $_UTF8->decode($r, $UTF8_CHECK) : $r;
        }
    }
}

1;

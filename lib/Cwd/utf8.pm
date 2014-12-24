package Cwd::utf8;
use strict;
use warnings;
use 5.010; # state

# ABSTRACT: Fully UTF-8 aware Cwd
# VERSION

=for test_synopsis
my $file;

=head1 SYNOPSIS

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

B<Note:> Replacement of functions is not done on DOS and OS/2
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


=head1 SEE ALSO

=for :list
* L<Cwd>
* L<File::Find::utf8>
* L<utf8::all>

=cut

use Cwd qw();
use Encode;

my @EXPORT = qw(cwd getcwd fastcwd fastgetcwd);
push @EXPORT, qw(getdcwd) if $^O eq 'MSWin32';
my @EXPORT_OK = qw(chdir abs_path fast_abs_path realpath fast_realpath);

# Holds the pointers to the original version of redefined functions
state %_orig_functions;

# Current package
my $current_package = __PACKAGE__;

# Original package (i.e., the one for which this module is replacing the functions)
my $original_package = $current_package;
$original_package =~ s/::utf8$//;

sub import {
    # Target package (i.e., the one loading this module)
    my $target_package = caller;

    no strict qw(refs); ## no critic (TestingAndDebugging::ProhibitNoStrict)
    no warnings qw(redefine);

    # If run on the DOS or OS/2 platform, ignore overriding functions silently.
    # These platforms do not (properly) suppport utf-8 filenames...
    unless ($^O eq 'dos' or $^O eq 'os2') {
        no strict qw(refs); ## no critic (TestingAndDebugging::ProhibitNoStrict)
        no warnings qw(redefine);

        # Redefine each of the functions to their UTF-8 equivalent
        for my $f (@EXPORT, @EXPORT_OK) {
            # If we already have the _orig_function, we have redefined the function
            # in an earlier load of this module, so we need not do it again
            unless ($_orig_functions{$f}) {
                $_orig_functions{$f} = \&{$original_package . '::' . $f};
                *{$original_package . '::' . $f} = sub { return _utf8_cwd($f, @_); };
            }
        }
        $^H{$current_package} = 1; # Set compiler hint that we should use the utf-8 version
    }

    if ($#_) {
        # Check arguments
        my @invalid_exports;
        for my $f (@_[1..$#_]) {
            if (! grep /^$f$/, (':none', @EXPORT, @EXPORT_OK)) {
                push @invalid_exports, "$f is not exported by $current_package module";
            }
        }
        if (@invalid_exports) {
            require Carp;
            Carp::croak(join("\n", @invalid_exports)  . "\nCan't continue after import errors");
        }
    }

    # Export functions to target package
    unless ($#_ && grep /^:none$/, @_[1..$#_]) {
        for my $f ($#_ ? @_[1..$#_] : @EXPORT) {
            *{$target_package . '::' . $f} = \&{$original_package . '::' . $f};
        }
    }
}

sub unimport {
    # If run on the dos/os2/windows platform, ignore overriding functions silently.
    # These platforms do not (properly) suppport utf-8 filenames...
    unless ($^O eq 'Win32' or $^O eq 'dos' or $^O eq 'os2') {
        $^H{$current_package} = 0; # Set compiler hint that we should not use the utf-8 version
    }
}

sub _utf8_cwd {
    my $func = shift;
    my $hints = (caller 1)[10]; # Use caller level 1 because of the added anonymous sub around call
    if (! $hints->{$current_package}) {
        # Use original function if we're not using Cwd::utf8 in calling package
        return $_orig_functions{$func}->(@_);
    } elsif (wantarray) {
        return map { decode('UTF-8' ,$_) } $_orig_functions{$func}->(map { encode('UTF-8', $_) } @_);
    } else {
        return decode('UTF-8', $_orig_functions{$func}->(map { encode('UTF-8', $_) } @_));
    }
}

1;

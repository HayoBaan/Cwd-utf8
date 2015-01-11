#!perl
use strict;
use warnings;
use Test::Warn;
use Test::Exception tests => 3;

# Tests if setting $Cwd::utf8::UTF8_CHECK has the required result

use Encode ();
use Cwd::utf8 qw(abs_path);

# Argument to abs_path with an illegal Unicode character
my $abs_path_arg = "Illegal \x{d800} character";

# Croak on faulty utf-8
{
    Test::Exception::throws_ok
          {
              abs_path($abs_path_arg);
          }
          qr/"\\x\{d800\}" does not map to utf8/,
          'croak on encoding error (default)';
}

# Warn on faulty utf-8
{
    local $Cwd::utf8::UTF8_CHECK = Encode::FB_WARN;
    Test::Warn::warning_is
          {
              abs_path($abs_path_arg);
          }
          qq("\\x\{d800\}" does not map to utf8),
          'warn on encoding error';
}

# Nothing on faulty utf-8
{
    local $Cwd::utf8::UTF8_CHECK = Encode::FB_DEFAULT;
    Test::Warn::warning_is
          {
              abs_path($abs_path_arg);
          }
          [],
          'no warn on encoding error';
}
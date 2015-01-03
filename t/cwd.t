#!perl
use strict;
use warnings;
use Test::More 0.96;
use Encode qw(decode FB_CROAK);

# Enable utf-8 encoding so we do not get Wide character in print
# warnings when reporting test failures
use open qw{:encoding(UTF-8) :std};

# Test files
my $test_root     = "corpus.tmp";
my $unicode_dir   = "\x{30c6}\x{30b9}\x{30c8}\x{30c6}\x{3099}\x{30a3}\x{30ec}\x{30af}\x{30c8}\x{30ea}";

if ($^O eq 'dos' or $^O eq 'os2') {
    plan skip_all => "Skipped: $^O does not have proper utf-8 file system support";
} else {
    # Create test files
    mkdir $test_root
        or die "Unable to create directory $test_root: $!"
        unless -d $test_root;
    mkdir "$test_root/$unicode_dir"
        or die "Unable to create directory $test_root/$unicode_dir: $!"
        unless -d "$test_root/$unicode_dir";
}

plan tests => 8;

use Cwd;
my $currentdir = getcwd();

# Test getcwd, cwd, fastgetcwd, fastcwd
chdir("$test_root/$unicode_dir") or die "Couldn't chdir to $test_root/$unicode_dir: $!";
for my $test (qw(getcwd cwd fastgetcwd fastcwd)) {
    subtest "utf8$test" => sub {
        plan tests => 2;

        my $dir = (\&{$test})->();

        my $utf8_dir;
        {
            use Cwd::utf8;
            $utf8_dir = (\&{$test})->();
        }
        isnt                 $dir            => $utf8_dir, "$test bytes != chars";
        is   decode('UTF-8', $dir, FB_CROAK) => $utf8_dir, "$test chars == chars";
    }
}

chdir($currentdir) or die "Can't chdir back to original dir $currentdir: $!";

# Test abs_path, realpath, fast_abs_path, fast_realpath
for my $test (qw(abs_path realpath fast_abs_path fast_realpath)) {
    subtest "utf8$test" => sub {
        plan tests => 3;

        use Cwd qw(abs_path realpath fast_abs_path fast_realpath);
        my $path = (\&{$test})->("$test_root/$unicode_dir");

        my $utf8_path;
        {
            use Cwd::utf8 qw(abs_path realpath fast_abs_path fast_realpath);
            $utf8_path = (\&{$test})->("$test_root/$unicode_dir");
        }
        like            $utf8_path => qr/\/$unicode_dir$/,   "$test found correct path";
        isnt                 $path            => $utf8_path, "$test bytes != chars";
        is   decode('UTF-8', $path, FB_CROAK) => $utf8_path, "$test chars == chars";
    }
}

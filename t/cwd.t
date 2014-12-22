#!perl
use strict;
use warnings;
use Test::More 0.96;
use Encode qw(decode FB_CROAK);

# Test files
my $test_root     = "test_files";
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

plan tests => 2;

# Test getcwd, cwd, fastcwd
subtest utf8cwd => sub {
    plan tests => 8;

    my $currentdir = getcwd();

    chdir("$test_root/$unicode_dir") or die "Couldn't chdir to $test_root/$unicode_dir: $!";
    use Cwd 3.30;
    my @cwdirs = (getcwd(), cwd(), fastcwd(), fastgetcwd());

    my @utf8_cwdirs;
    {
        use Cwd::utf8;
        @utf8_cwdirs = (getcwd(), cwd(), fastcwd(), fastgetcwd());
    }
    for (my $i=0 ; $i<4; $i++) {
        isnt $cwdirs[$i] => $utf8_cwdirs[$i];
        is   decode('UTF-8', $cwdirs[$i], FB_CROAK) => $utf8_cwdirs[$i];
    }

    chdir($currentdir) or die "Can't chdir back to original dir $currentdir: $!";
};

# Test abst_path, real_path, fast_abs_path
subtest utf8abs_path => sub {
    plan tests => 9;

    use Cwd 3.30;
    my @abs = (Cwd::abs_path("$test_root/$unicode_dir"), Cwd::realpath("$test_root/$unicode_dir"), Cwd::fast_abs_path("$test_root/$unicode_dir"));

    my @utf8_abs;
    {
        use Cwd::utf8;
        @utf8_abs = (Cwd::abs_path("$test_root/$unicode_dir"), Cwd::realpath("$test_root/$unicode_dir"), Cwd::fast_abs_path("$test_root/$unicode_dir"));
    }
    for (my $i=0 ; $i<3; $i++) {
        like $utf8_abs[$i] => qr/\/$unicode_dir$/;
        isnt $abs[$i] => $utf8_abs[$i];
        is   decode('UTF-8', $abs[$i], FB_CROAK) => $utf8_abs[$i];
    }
};

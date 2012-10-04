#! /usr/bin/env perl
use strict;
use Getopt::Long qw(:config bundling gnu_compat);

sub show_help {
	die "Usage: $0 <program> <short tests> [<long tests>]
-h --help       - help\n";
}

my ($help);

GetOptions(
	"h|help" => \$help,
) or show_help();
show_help if $help;

my ($program, $short_tests, $long_tests) = @ARGV;

my ($path) = $0 =~ /^(.*?)[^\/]+$/;
$path ||= "./";

print ">>>>>PROGRAMM CODE AND SHORT TESTS<<<<<\n";
system(sprintf(q[perl %sMT.pl %s -L 0 -p -l --default-state=00:0 < %s], $path, $program, $short_tests));

if ($long_tests) {
	print ">>>>>LONG TESTS<<<<<\n";
	system(sprintf(q[perl %sMT.pl %s -L 0 -pls --no-code --default-state=00:0 < %s], $path, $program, $long_tests));
}


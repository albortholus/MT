#! /usr/bin/env perl
use strict;
use Time::HiRes qw(usleep);
#use Data::Dumper;
use Getopt::Long qw(:config bundling gnu_compat);

use constant VERSION => 0.8;
use constant LATENCY => 500000;

sub show_help {
	die "Usage: $0 <filename> [-v|-s] [-L<NUMBER>] [-p] [-l] [--default-state=<STATE>] [-i] [-h]
-s --short      - short output (no full trace)
-v --verbose    - extrafull trace (show movement)
--no-code		- do not print code
-L --latency    - latency of run (make programm run faster or slower) (use --latency=### or -L###)
-p --pedantic   - pedantic mode
-l --locating   - enable head locating
-i --step       - step by step execution
--default-state - define default state - will be used in every run
--version       - show version number
-h --help       - help\n";
}

my ($short, $verbose, $pedantic, $locating, $step_by_step, $latency, $default_state, $version, $help, $no_code);

GetOptions(
	"s|short" => \$short,
	"v|verbose" => \$verbose,
	"L|latency:i" => \$latency,
	"p|pedantic" => \$pedantic,
	"l|locating" => \$locating,
	"i|step" =>  \$step_by_step,
	"default-state:s" => \$default_state,
	"version" => \$version,
	"h|help" => \$help,
	"no-code" => \$no_code,
) or show_help();
show_help if $help;
$latency = LATENCY unless defined $latency;
$default_state = [split /\:/, $default_state] if $default_state =~ /\:/;

my $file;
for (my $i = 0; $i < scalar @ARGV; $i++) {
	if ($ARGV[$i] !~ /^\-/) {
		if (-e $ARGV[$i]) {
			$file = $ARGV[$i];
			delete $ARGV[$i];
			last;
		} else {
			warn "File '$ARGV[$i]' does not exist\n";
		}
	}
}
show_help() if !$file;

my %MT;

open FH, $file or die "Could not open file $file\n";

my $i = 0;
while (my $ln = <FH>) {
	chomp $ln;
	$i++;
	if ($ln =~ /^\s*$/ || $ln =~ /^\#/) {
	    next;
	} else {
		my ($state, $symbol, $action, $nstate) = $ln =~ /^\s*([^\s]+)\,(.)\,(.)\,([^\s]+)\s*$/;
	    die "Incorrect line($i): '$ln'\n"
		if (!defined $state || !defined $symbol || !defined $action || !defined $nstate);
	    $MT{$state}->{$symbol} = [$action, $nstate];
	}
}

close FH;

if (ref $default_state eq 'ARRAY') {
	for my $st (@$default_state) {
		if (defined $MT{$st}) {
			$default_state = $st;
			last;
		}
	}
}

#print Dumper \%MT;
my $max_l_s = 0;
foreach my $s (sort keys %MT) {
    $max_l_s = length $s if length $s > $max_l_s;
}

unless ($no_code) {
	my @programm = ();
	foreach my $s (sort keys %MT) {
	    foreach  my $ss (sort keys %{$MT{$s}}) {
			push @programm,
				sprintf "<%${max_l_s}s,%1s,%1s,%s>   ",
					$s, $ss, $MT{$s}->{$ss}->[0], $MT{$s}->{$ss}->[1];
    	}
	}
	my $n_in_row = int(80 / ($max_l_s*2+10));
	my $n_in_column = int(((scalar @programm) / $n_in_row)) + 1;
	my $row = 0;
	foreach my $row (0..$n_in_column) {
		foreach my $col (0..$n_in_row) {
			if ($col*$n_in_column + $row < scalar @programm) {
				print $programm[$col*$n_in_column + $row];
			}
		}
		print "\n";
	}
}

my $prev_ln = " ";

while (1) {
    my $state = "";
    my @tape = ();
    my $head = 0;
    
    print (("="x40)."\n");

	if (defined $default_state) {
		$state = $default_state;
	} else {    
		print "Input start state\n";
    	$state = <STDIN>;
    	chomp $state;
    	last if !length $state;
	}

    print "Input tape\n";
    my $ln = <STDIN>;
    chomp $ln;
    last if !length $ln;

	if ($ln eq '<<<') {
		$ln = $prev_ln;
		print "$ln\n";
	}
    $ln =~ s/\s+$//;
    $ln = " $ln" if $ln !~ /^ / && !$pedantic;

	if ($locating) {
    	print "Input location\n";
    	my $ln = <STDIN>;
    	chomp $ln;
		my $h = 0;
		foreach my $dot (split //, $ln) {
			if ($dot eq '.' || $dot eq ' ') {
				$h++;
			} elsif ($dot eq '^') {
				$head = $h;
				last;
			} else {
				warn "Incorrect symbol '$dot'. String like '.....^' expected\n";
				last;
			}
		}
	}

    @tape = split //, "$ln ";
    $head = scalar @tape - 1 if !$head;

    print_state(\@tape, $state, $head);

    my $symbol = $tape[$head];
    $i = 0;
    my $move = 0;
    while (defined $MT{$state}->{$symbol} || defined $MT{$state}->{'*'}) {
		my $do = $MT{$state}->{$symbol} || $MT{$state}->{'*'};
		my $pre_state = [$state, $tape[$head]];
		if ($do->[0] eq '<') {
		    $move = 1;
		    die "Tape is only one way infinite!\n" if ($head == 0);
		    $head--;
		} elsif ($do->[0] eq '>') {
		    $move = 1;
		    die "Your program is doing something evil!\n" if ($head > 100000);
		    $head++;
		    push @tape, " " if $head == scalar @tape;
		} elsif ($do->[0] eq '#') {
			$move = 0;
		} else {
		    $move = 0;
		    $tape[$head] = $do->[0];
		}
		$state = $do->[1];
		$symbol = $tape[$head];
		print_state(\@tape, $state, $head) if !$short && (!$move || $verbose);
		if (
			($state eq '##') ||														# special state
			($pre_state->[0] eq $state && $pre_state->[1] eq $symbol && !$move) || 	# rule doing nothing
			($do->[0] eq '#') ||													# action 'stop'
			0) {
			if ($pedantic && !is_on_end(\@tape, $head)) {
				print "\n-==FINISHED ON INCORRECT POSITION==-\n";
			} else {
		    	print "\n+==WORK CORRECTLY FINISHED==+\n";
			}
		    $i = -1;
		    last;
        }
    }
	$prev_ln = join "", @tape;
    print_state(\@tape, $state, $head) if $short; 
    if ($i != -1) {
		print "\n-==COULD NOT FIND NEXT COMMAND==-\n";
    }
    
}

sub is_on_end {
	my $tape = shift;
	my $position = shift;
	foreach my $p ($position..(scalar @{$tape} - 1)) {
		return 0 if $tape->[$p] ne ' ';
	}
	return 1;
}

sub print_state {
	my $tape = shift;
	my $state = shift;
	my $position = shift;
	
	print ((" "x($max_l_s + 1)).(join "", @{$tape})."\n");
	printf "%${max_l_s}s:".(" "x$position)."^".($step_by_step ? "" : "\n"), $state;
	if ($step_by_step) {
		my $x = <STDIN>;
		chomp $x;
	} else {
		usleep $latency;
	}
}

=pod

ChangeLog

v.0.7
* fix for "0" default state
* support '#' action - stop machine
* --no-code key
* spaces instead of dots in locating

v.0.6
* use Getopt::Long

v.0.5
* use previous final tape as new input tape
   input '<<<' as input tape
* head locating
   input something like '.......^'
* default state
   will be used on every programm run.
* long option names
* step-by-step execution
   after every state output will wait for newline input

v.0.4
* pedantic mode:
   check final position;
   do not add leading space
* program output in columns (not rows)
* filename in any part of command line

=cut


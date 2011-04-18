#!/usr/bin/perl -w
# $Id$

use strict;
use warnings;
use Data::Dumper;
use Expect;

my $prompt = qr/^\w+@\w+-\d+:.+\$\s$/m;
my $timeout = 10;
my $command = "ssh -t rennes.g5k oarsub -I -l core=1,walltime=0:05:00";

my $exp = new Expect;
$exp->raw_pty(0);
$exp->log_user(1);
$exp->exp_internal(0);
$exp->restart_timeout_upon_receive(1);

my $jobid;
my $nodefile;
my $cpuset;

$exp ->spawn($command)
 or die "Cannot spawn $command: $!\n";
$exp->expect($timeout, 
    [ qr/^Generate a job key...\r\n$/m => sub { 
            my $exp = shift;
            print "--> OK generate job key\n";
            exp_continue;
        }
    ],
    [ qr/^OAR_JOB_ID=(\d+)\r\n$/m => sub {
            my $exp = shift;
            $jobid = ($exp->matchlist())[0];
            print "--> OK got job id: $jobid\n";
            exp_continue;
        }
    ],
    [ $prompt => sub { 
            my $exp = shift;
#            print "--> OK got prompt\n";
        }
    ],
    [ eof => sub {
            my $exp = shift;
            die "--> Premature EOF !\n";
        }
    ],
    [ timeout => sub {
            my $exp = shift;
            die "--> Timeout !\n";
        }
    ]
);
$exp->send("echo \$OAR_NODEFILE\n");
$exp->expect($timeout, 
    [ qr/^(.+\/$jobid)\r$/m => sub {
            my $exp = shift;
            $nodefile = ($exp->matchlist())[0];
            print "--> OK got nodefile: $nodefile\n";
            exp_continue;
        }
    ],   
    [ $prompt => sub { 
            my $exp = shift;
#            print "--> OK got prompt\n";
        }
    ],
    [ eof => sub {
            my $exp = shift;
            die "--> Premature EOF !\n";
        }
    ],
    [ timeout => sub {
            my $exp = shift;
            die "--> Timeout !\n";
        }
    ]
);

$exp->send("cat /proc/self/cpuset\n");
$exp->expect($timeout, 
    [ qr/^(\/oar\/\w+_$jobid)\r$/m => sub {
            my $exp = shift;
            $cpuset = ($exp->matchlist())[0];
            print "--> OK got cpuset: $cpuset\n";
            exp_continue;
        }
    ],   
    [ $prompt => sub { 
            my $exp = shift;
#            print "--> OK got prompt\n";
        }
    ],
    [ eof => sub {
            my $exp = shift;
            die "--> Premature EOF !\n";
        }
    ],
    [ timeout => sub {
            my $exp = shift;
            die "--> Timeout !\n";
        }
    ]
);
#print "--> Entering interactive session\n";
#$exp->interact(\*STDIN, '\cq' );
#print "--> Interactive session ended\n";
$exp->send(eof);

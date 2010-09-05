#!/usr/bin/perl -w

use Test::More tests => 5;

# Test the include path
use_ok(Job);

# Test the instantiation of a empty job
my $job = Job->new;
ok( defined $job );
ok($job->isa('Job'));

# Test the instantiation of a job from a hash
my $hash = '{"stdout_file":"OAR.1.stdout","stderr_file":"OAR.1.stderr","directory":"/root","state":"toLaunch","command":"date"}';

$job = Job->new($hash);
ok (defined $job);
ok ($job->isa('Job'));

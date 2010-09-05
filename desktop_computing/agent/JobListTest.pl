#!/usr/bin/perl -w

use Test::More tests => 3;
use Test::MockObject;
use JSON;

# Set up the hash that should come from the server
my $hash = decode_json '{   "1" : {      "stderr_file" : "OAR.1.stderr",      "stdout_file" : "OAR.1.stdout",      "directory" : "/root",      "command" : "date",      "state" : "toLaunch"   }}';

# Tests the import of the module
use_ok(JobList);

# Tests the constructor
my $list = JobList->new($hash);
ok( defined $list );
ok($list->isa('JobList'));

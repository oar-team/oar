#!/usr/bin/perl -w

use Test::More tests => 3;
use Test::MockObject;

# Setting up REST::Client's mock
my $mock = Test::MockObject->new;
$mock->set_true('GET');
$mock->mock('responseContent', sub { '{   "1" : {      "stderr_file" : "OAR.1.stderr",      "stdout_file" : "OAR.1.stdout",      "directory" : "/root",      "command" : "date",      "state" : "toLaunch"   }}'});

# Tests the import of the module
use_ok(OarClient);

# Tests the constructor
my $client = OarClient->new_from_client($mock);
ok( defined $client );
ok($client->isa('OarClient'));

print $client->get_jobs_to_run;



#!/usr/bin/perl -w

use REST::Client;
 
#The basic use case
my $client = REST::Client->new();
$client->GET('http://192.168.56.101/oarapi/resources/nodes/node2/jobs.json');
print $client->responseContent();
  


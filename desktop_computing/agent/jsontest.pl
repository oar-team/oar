#!/usr/bin/perl -w

use JSON;

my $utf8_encoded_json_text = '{   "1" : {      "stderr_file" : "OAR.1.stderr",      "stdout_file" : "OAR.1.stdout",      "directory" : "/root",      "command" : "date",      "state" : "toLaunch"   }}'
;

$perl_hash_or_arrayref = decode_json $utf8_encoded_json_text;

foreach $item (values %$perl_hash_or_arrayref) {
  print encode_json $item;
}

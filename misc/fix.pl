#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use SQL::Statement;
my $where = "toto IN ('a', 'b') AND NOT titi IN ('c', 'd') AND tutu IN ('e', 'f')";

my $sql = "SELECT * FROM resources WHERE $where";
my $parser = SQL::Parser->new();
my $stmt = SQL::Statement->new($sql,$parser);

print "SQL: $sql\n";
print "\$stmt->{list_ids}: " . Dumper($stmt->{list_ids});
print "\$stmt->{where_cols}: " . Dumper($stmt->{where_cols});

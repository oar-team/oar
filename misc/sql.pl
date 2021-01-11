#!/usr/bin/perl -w
use strict;
use warnings;
use Data::Dumper;
use SQL::Statement;
#my $where = "exotic = 'NO' AND ((type = '\"default\"' OR type = 'disk') AND host IN ('node-1', 'node-2') AND gpu_count > 0) AND (NOT gpu_model = 'tesla' OR exotic = 'YES') AND cpu IN ( 'toto', 'titi' ) AND core IN (1,2)";
#my $where = 'exotic = "NO" AND ((type = "default" OR type = "disk") AND host IN ("node-1", "node-2") AND gpu_count > 0) AND (NOT gpu_model = "tesla" OR exotic = "YES") AND cpu IN ( "toto", "titi" ) AND core IN (1,2)';
#my $where = "toto IN ('a', 'b') AND NOT titi IN ('c', 'd') AND tutu IN ('e', 'f')";
my $where = 'toto IN ("a", "b") OR titi IN (1, 2) OR tutu IN ("3", "4")';
#my $where = "toto IN ('a', 'b') OR titi IN (1, 2) OR tutu IN ('3', '4')";

my $sql = "SELECT * FROM resources WHERE $where";
#my $sql = "SELECT * FROM resources WHERE exotix = 'NO' AND ((type = 'default' OR type = 'disk') AND host = 'node-1' AND gpu_count > 0) AND gpu_model LIKE 'tesla%'";
my $parser = SQL::Parser->new();
my $stmt = SQL::Statement->new($sql,$parser);

sub where_str($);

sub where_str($) {
    my $where_struct = shift;
    if (ref($where_struct) eq 'ARRAY') {
        return "(" . join(", ", map { where_str($_) } @$where_struct). ")";
    }
    if (ref($where_struct) eq 'HASH') {
        if (exists($where_struct->{op})) {
            if (ref($where_struct->{arg1}) eq 'HASH' and exists($where_struct->{arg1}->{op}) or 
                ref($where_struct->{arg2}) eq 'HASH' and exists($where_struct->{arg2}->{op}) or
                $where_struct->{neg}) {
                my $neg = ($where_struct->{neg}) ? "NOT " : "";
                return "$neg(" . where_str($where_struct->{arg1}) . " " . $where_struct->{op} . " " . where_str($where_struct->{arg2}) . ")";
            }
            return where_str($where_struct->{arg1}) . " " . $where_struct->{op} . " " . where_str($where_struct->{arg2});
        }
        if ($where_struct->{type} eq 'number') {
            return $where_struct->{value};
        } elsif ($where_struct->{type} eq 'string') {
            return "'" . $where_struct->{value} . "'";
        } else {
            return $where_struct->{fullorg};
        }
    }
    die "Should not be there !";
}
#print Dumper($stmt->where_hash);
#print "==============================================================================\n";
#print $where . "\n";
#print "==============================================================================\n";
#print where_str($stmt->where_hash)."\n";
print Dumper($stmt);
#print Dumper($stmt->{list_ids});
#print Dumper($stmt->{where_cols});


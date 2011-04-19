package oarversion;
require Exporter;

my $OARVersion = "2.4.4+dev3.0a423cf";
my $OARName = "Thriller";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

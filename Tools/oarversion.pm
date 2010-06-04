package oarversion;
require Exporter;

my $OARVersion = "2.4.3";
my $OARName = "Thriller";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

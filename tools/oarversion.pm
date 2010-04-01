package oarversion;
require Exporter;

my $OARVersion = "2.5.0";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

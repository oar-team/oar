package oarversion;
require Exporter;

my $OARVersion = "2.5.0+dev300.2009cdd";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

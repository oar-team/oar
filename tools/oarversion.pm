package oarversion;
require Exporter;

my $OARVersion = "2.5.0+dev281.3e2f84f";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

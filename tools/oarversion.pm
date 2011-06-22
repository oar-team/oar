package oarversion;
require Exporter;

my $OARVersion = "2.5.0+dev364.9673911";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

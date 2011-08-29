package OAR::Version;
require Exporter;

my $OARVersion = "2.5.0+dev429.883bf66";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

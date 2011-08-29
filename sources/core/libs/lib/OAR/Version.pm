package OAR::Version;
require Exporter;

my $OARVersion = "2.5.0+dev424.cf9a1be";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

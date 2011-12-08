package OAR::Version;
require Exporter;

my $OARVersion = "2.5.0+rc1";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

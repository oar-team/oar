package OAR::Version;
require Exporter;

my $OARVersion = "2.6.0-dev";
my $OARName = "Unknown";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

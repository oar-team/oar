package OAR::Version;
require Exporter;

my $OARVersion = "2.5.10+g5k18";
my $OARName = "Liberty hope";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

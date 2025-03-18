package OAR::Version;
require Exporter;

my $OARVersion = "2.6.1+rc1";
my $OARName    = "Liberty hope";

sub get_version() {
    return $OARVersion . " (" . $OARName . ")";
}

return 1;

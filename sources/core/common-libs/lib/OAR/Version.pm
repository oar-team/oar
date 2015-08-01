package OAR::Version;
require Exporter;

my $OARVersion = "2.5.5+rc1";
my $OARName = "Froggy Summer";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

package OAR::Version;
require Exporter;

my $OARVersion = "2.5.4+rc5";
my $OARName = "Froggy Summer";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

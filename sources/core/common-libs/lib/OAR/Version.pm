package OAR::Version;
require Exporter;

my $OARVersion = "2.5.8";
my $OARName = "Canicule";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

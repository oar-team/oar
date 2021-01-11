package OAR::Version;
require Exporter;

my $OARVersion = "2.5.9";
my $OARName = "Canicule";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

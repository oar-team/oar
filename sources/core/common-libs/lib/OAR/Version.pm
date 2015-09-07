package OAR::Version;
require Exporter;

my $OARVersion = "2.5.5";
my $OARName = "The Force Awakens";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

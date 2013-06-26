package OAR::Version;
require Exporter;

my $OARVersion = "2.5.3";
my $OARName = "Frog Master";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

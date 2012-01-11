package OAR::Version;
require Exporter;

my $OARVersion = "2.5.1";
my $OARName = "";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

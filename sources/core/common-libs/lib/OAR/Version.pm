package OAR::Version;
require Exporter;

my $OARVersion = "2.5.6+rc3";
my $OARName = "Winter is coming";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

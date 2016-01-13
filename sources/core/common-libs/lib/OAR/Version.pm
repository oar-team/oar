package OAR::Version;
require Exporter;

my $OARVersion = "2.5.6";
my $OARName = "Winter is not coming";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

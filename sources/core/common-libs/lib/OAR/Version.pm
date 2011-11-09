package OAR::Version;
require Exporter;

my $OARVersion = "2.5.0+dev487.f014a74";
my $OARName = "SID";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

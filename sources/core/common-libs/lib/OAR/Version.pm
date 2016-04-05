package OAR::Version;
require Exporter;

my $OARVersion = "2.5.7";
my $OARName = "Winter was not coming";

sub get_version(){
    return $OARVersion." (".$OARName.")";
}

return 1;

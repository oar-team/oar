# $Id: oarversion.pm,v 1.9 2005/06/01 16:20:42 capitn Exp $
package oarversion;
require Exporter;

my $OARVersion = "1.6.1";

sub get_version(){
    return $OARVersion;
}

return 1;

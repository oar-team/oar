#!/usr/bin/perl
use Data::Dumper;
use CGI qw/:standard/;
use YAML;

## CONFIGURATION SECTION ##

my $oargridstatCmd = "/usr/local/bin/oargridstat";

## END CONFIGURATION ##

open(CMD, "$oargridstatCmd --monitor -Y |") || die("Can not execute $oargridstatCmd.\n");
# All informations about each clusters are stored here
my $line;
while (<CMD>){
    $line .= $_;
}
my $allInfo = YAML::Load($line);


print(header, start_html('oargridmonitor'));

#print(Dumper($allInfo));

print("<html>\n<head>\n<meta content=\"text/html; charset=ISO-8859-1\"\n http-equiv=\"content-type\">\n  <title>oargridmonitor</title>\n</head>\n<body>\n");

foreach my $cluster (keys(%{$allInfo})){
    print("<h1>$cluster</h1>\n");
    print("<ul>\n");
    print("<li>free nodes = $$allInfo{$cluster}{stats}{freeNodes}</li>\n");
    print("<li>busy nodes = $$allInfo{$cluster}{stats}{busyNodes}</li>\n");
    print("<li>jobs :</li>\n");
    print("</ul>\n");
    
    foreach my $j (keys(%{$$allInfo{$cluster}{jobs}})){
        print("job $j with a weight of $$allInfo{$cluster}{jobs}{$j}->{weight} on nodes : [ ");
        foreach my $n (@{$$allInfo{$cluster}{jobs}{$j}->{hostnames}}){
            print("$n ");
        }
        print("]<br>\n");
    }
}


print("</body>\n</html>");


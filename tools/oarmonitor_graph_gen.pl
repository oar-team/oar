#!/usr/bin/perl
# $Id$

use DBI;
use strict;
use warnings;
use POSIX qw(strftime);
use Getopt::Long;

my $Db_type = "Pg";
my $Db_host = "127.0.0.1";
my $Db_name = "oar";
my $Db_user = "oar";
my $Db_pass = "oar";

Getopt::Long::Configure("gnu_getopt");
my $Job_id;
my $sos;
GetOptions (
            "job_id|j=i" => \$Job_id,
            "help|h" => \$sos,
           );

# Display command help
sub usage {
    print <<EOS;
Usage: $0 [-h] -j jobid
Create images from the monitoring data for the specified job.
Options:
  -j, --job_id      job id to monitor
  -h, --help        show this help screen
EOS
}

if (defined($sos)){
    usage();
    exit(0);
}

if (!defined($Job_id)){
    warn("[ERROR] You must specify a job id\n\n");
    usage();
    exit(1);
}

my $directory = "OAR.$Job_id.monitoring";
mkdir($directory) or die("[Error] Cannot create $directory; Is this directory already exist?\n");
chdir($directory) or die("[Error] Cannot go into $directory\n");

my $Db = DBI->connect("DBI:$Db_type:database=$Db_name;host=$Db_host", $Db_user, $Db_pass, {'InactiveDestroy' => 1, 'PrintError' => 1});


my $sth = $Db->prepare("    SELECT window_stop, network_address, subvalue
                            FROM monitoring_generic
                            WHERE
                                type = \'job_id\' AND
                                subtype = \'cpuset_cpu_percent\' AND
                                value = $Job_id
                            ORDER BY network_address
                       ");
$sth->execute();
my %files;
while (my @ref = $sth->fetchrow_array()) {
    if (open(FILE,">> $ref[0].cpuset.dat")){
        print(FILE "$ref[1] $ref[2]\n");
        close(FILE);
        $files{"$ref[0]"} = 1;
    }else{
        die("Cannot write $ref[0].dat\n");
    }
}

$Db->disconnect();

print("Generating PNG files ");
foreach my $f (keys(%files)){
    my $date = strftime("%F %T",localtime($f));
    open(CMD, "|gnuplot");
    print CMD <<EOC;
set auto x
set style fill solid 0.2
set style histogram cluster gap 1
set style data histogram
set terminal png
set output "$f.png"
set yrange [0:100]
set xlabel "hosts"
set ylabel "Cpus %"
set title "cpuset consumption: $date"
#set xtic rotate by -45
set nokey
plot "$f.cpuset.dat" using 2:xtic(1)
EOC
    close(CMD);
    print(".");
}
print("\n");

system('mencoder "mf://*.png" -mf fps=20:w=1000:h=1000:type=png -o cpuset_cpu.avi -ovc lavc -lavcopts vcodec=mpeg4');

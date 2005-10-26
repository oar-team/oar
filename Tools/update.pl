#!/usr/bin/perl
# $Id: update.pl,v 1.34 2004/08/24 15:56:56 neyron Exp $


use strict;
use warnings;
use Data::Dumper;
use Sys::Hostname;
use Getopt::Std;
use DBI;
use oar_conflib qw(init_conf get_conf is_conf);

# Se connecte à la base et renvoie l'identificateur de connexion
sub connect() {
    # Connect to the database.
    init_conf("oar.conf");
    my $host = get_conf("database_host");
    my $name = get_conf("database_name");
    my $user = get_conf("database_username");
    my $pwd = get_conf("database_userpassword");

    return DBI->connect("DBI:mysql:database=$name;host=$host", $user, $pwd, {'RaiseError' => 1});
}


my $host = hostname;
my $dbh = &connect();
# Relative path of the package
my @relativePathTemp = split(/\//, $0);
my $relativePath = "";
for (my $i = 0; $i < $#relativePathTemp; $i++){
    $relativePath = $relativePath.$relativePathTemp[$i]."/";
}
$relativePath = $relativePath."../";

# relative path of each file to install
# file => relative install path
my $installPath = "/usr/local/OAR";
my $filePath = {
                'Almighty/Almighty' => 'bin/Almighty',
                'Leon/Leon' => 'bin/Leon',
                'Runner/oarexec' => 'bin/oarexec',
                'Runner/oarexecuser.sh' => 'bin/oarexecuser.sh',
                'Leon/oarverify' => 'bin/oarverify',
                'Leon/oarkill' => 'bin/oarkill',
                'Runner/bipbip' => 'bin/bipbip',
                'Runner/ping_checker.pm' => 'lib/ping_checker.pm',
                'Qfunctions/oarnodes' => 'bin/oarnodes',
                'Qfunctions/oardel' => 'bin/oardel',
                'Qfunctions/oarstat' => 'bin/oarstat',
                'Qfunctions/oarsub' => 'bin/oarsub',
                'Runner/runner' => 'bin/runner',
                'Sarko/sarko' => 'bin/sarko',
                'Scheduler/oar_sched_fifo' => 'bin/oar_sched_fifo',
                'Scheduler/Gant.pm' => 'lib/Gant.pm',
                'Scheduler/oar_sched_gant' => 'bin/oar_sched_gant',
                'ConfLib/oar_conflib.pm' => 'lib/oar_conflib.pm',
                'Iolib/oar_iolib.pm' => 'lib/oar_iolib.pm',
                'Tools/oar_uninstall' => 'bin/oar_uninstall',
                'Scheduler/oar_meta_sched' => 'bin/oar_meta_sched' ,
                'Scheduler/oar_sched_fifo_queue' => 'bin/oar_sched_fifo_queue',
                'Scheduler/oar_sched_fifo_queue_killer' => 'bin/oar_sched_fifo_queue_killer',
                'Scripts/oar_prologue' => 'scripts/oar_prologue' ,
                'Scripts/oar_epilogue' => 'scripts/oar_epilogue' ,
                'Scripts/oar_diffuse_script' => 'scripts/oar_diffuse_script' ,
                'Scripts/oar_epilogue_local' => 'scripts/oar_epilogue_local' ,
                'Scripts/oar_prologue_local' => 'scripts/oar_prologue_local' ,
                'Qfunctions/oarhold' => 'bin/oarhold',
                'Qfunctions/oarresume' => 'bin/oarresume',
                'Qfunctions/oarnodesetting' => 'bin/oarnodesetting',
                'Qfunctions/oarnotify' => 'bin/oarnotify',
                'Judas/oar_Judas.pm' => 'lib/oar_Judas.pm',
                'Docs/man/oardel.1' => 'man/oardel.1',
                'Docs/man/oarnodes.1' => 'man/oarnodes.1',
                'Docs/man/oarresume.1' => 'man/oarresume.1',
                'Docs/man/oarstat.1' => 'man/oarstat.1',
                'Docs/man/oarsub.1' => 'man/oarsub.1',
                'Docs/man/oarhold.1' => 'man/oarhold.1',
                'NodeChangeState/NodeChangeState' => 'bin/NodeChangeState'
};

# Lists all files for which execute chmod +s on
my $cmdCHMODS = [ "Almighty/Almighty", "Qfunctions/oarsub", "Qfunctions/oardel", "Qfunctions/oarstat", "Qfunctions/oarnodes",
                    "Qfunctions/oarhold", "Qfunctions/oarresume", "Qfunctions/oarnotify" ];

chdir("$relativePath");
open(CMD,"pwd|");
my $pwd = <CMD>;
chomp($pwd);
print("pwd=$pwd\n");
close(CMD);

my %opt;
getopts('i:f:m:h',\%opt);

#my $oarNodes = "";
my @oarNodes ;
if (!defined($opt{f})){
    my $sth = $dbh->prepare("SELECT hostname FROM nodes WHERE state = \"Alive\"");
    $sth->execute();
    #if (! open(FILE,">$ENV{HOME}/oar_nodes_tmp.list")){
    #    die("Can t write to file $ENV{HOME}/oar_nodes_tmp.list\n");
    #}
    while (my $ref = $sth->fetchrow_hashref()) {
        #print(FILE "$ref->{'hostname'}\n");
        #$oarNodes .= "-m $ref->{'hostname'} ";
        push(@oarNodes, $ref->{'hostname'});
    }
    #close(FILE);
    #$oarNodes = "$ENV{HOME}/oar_nodes_tmp.list";

}else{
    my $oarNodesFile;
    if (-r "$opt{f}"){
        $oarNodesFile = "$opt{f}";
    }elsif(-r "./Tools/$opt{f}"){
        $oarNodesFile = "./Tools/$opt{f}";
    }else{
        die("Can t find node file (-f option)\n");
    }
    open(FILE,"<$oarNodesFile");
    while (<FILE>){
        chomp;
        push(@oarNodes, $_);
    }
    close(FILE);
}

my $filePathTmp;
if (!defined($opt{m})){
    $filePathTmp = $filePath;
}else{
    if (defined($$filePath{$opt{m}})){
        $filePathTmp = { "$opt{m}" => "$$filePath{$opt{m}}" };
    }else{
        print("You must enter one of this value after the -m option :\n");
        foreach my $i (sort(keys(%{$filePath}))){
            print("\t$i\n");
        }
        exit(0);
    }
}

if (defined($opt{h})){
    print("usage : update.pl [-f node_list_file] [-m one_specific_module] [-i installPath]\n");
    exit(0);
}

if (defined($opt{i})){
    $installPath = $opt{i};
}else{
    print("Be carefull : I use the default remote install path --> $installPath\nIf you want to specify an other, use the -i option\n");
    print("PRESS RETURN TO CONTINUE\n");
    <STDIN>;
}

my $cmdSup ;
foreach my $i (keys(%{$filePathTmp})){
    $cmdSup = " sleep 0; ";
    #foreach my $j (@$cmdCHMODS){
    #    if ( $j eq $i ){
    #        print("\tchmod +s $installPath/$$filePathTmp{$i}\n");
    #        $cmdSup = "sudo chmod +s $installPath/$$filePathTmp{$i}";
    #    }
    #}
    #system("sentinelle -v -cssh $oarNodes -- \"scp $host:$pwd/$i $installPath/$$filePathTmp{$i}; $cmdSup\"");
    foreach my $n (@oarNodes){
        print("$n\n");
        #system("/bin/sh -c \"( ssh $n \\\"scp $host:$pwd/$i $installPath/$$filePathTmp{$i} && $cmdSup\\\") || echo \\\"/!\\ COMMAND RETURN $? on $host\\\" \"");
        #print("/bin/sh -c \" ( ssh $n \\\"scp $host:$pwd/$i $installPath/$$filePathTmp{$i} && $cmdSup\\\" || echo \\\"/!\\ BAD EXECUTION on $host\\\" ) \"");
        system("/bin/sh -c \" ssh $n \\\"scp $host:$pwd/$i $installPath/$$filePathTmp{$i} && $cmdSup\\\" || echo \\\"/!\\ BAD EXECUTION on $host\\\" \"");
    }
    print("\nCopy $i --> $installPath/$$filePathTmp{$i}\n");
}


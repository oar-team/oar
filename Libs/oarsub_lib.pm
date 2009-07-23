use strict;
use warnings;
use oarversion;
use oar_Tools;
use oar_iolib;
use IO::Socket::INET;

package oarsublib;

my $base;

sub open_db_connection(){
	$base  = iolib::connect_ro();
}
sub close_db_connection(){
	iolib::disconnect($base);
}

#Used when we must have a response from the server
sub init_tcp_server(){
    my $server = IO::Socket::INET->new( Proto    => 'tcp',
                                        Reuse => 1,
                                        Listen => 1
                                      ) or die("/!\\ Cannot initialize a TCP socket server.\n");
    my $server_port = $server->sockport();
    return($server,$server_port);
}

#Read user script and extract OAR submition options
sub scan_script($$){
    my $file = shift;
	my $Initial_request_string = shift;
    my %result;
    my $error = 0;
    
    ($file) = split(" ",$file);
    my $lusr= $ENV{OARDO_USER};
    $ENV{OARDO_BECOME_USER} = $lusr;
    if (open(FILE, "oardodo cat $file |")){

        if (<FILE> =~ /^#/){
            while (<FILE>) {
                if ( /^#OAR\s+/ ){
                    my $line = $_;
                    if ($line =~ m/^#OAR\s+(-l|--resource)\s*(.+)\s*$/m){
                        push(@{$result{resources}}, $2);
                    }elsif ($line =~ m/^#OAR\s+(-q|--queue)\s*(.+)\s*$/m) {
                        $result{queue} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-p|--property)\s*(.+)\s*$/m) {
                        $result{property} = $2;
                    }elsif ($line =~ m/^#OAR\s+(--checkpoint)\s*(\d+)\s*$/m) {
                        $result{checkpoint} = $2;
                    }elsif ($line =~ m/^#OAR\s+(--notify)\s*(.+)\s*$/m) {
                        $result{notify} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-t|--type)\s*(.+)\s*$/m) {
                        push(@{$result{types}}, $2);
                    }elsif ($line =~ m/^#OAR\s+(-d|--directory)\s*(.+)\s*$/m) {
                        $result{directory} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-n|--name)\s*(.+)\s*$/m) {
                        $result{name} = $2;
                    }elsif ($line =~ m/^#OAR\s+(--project)\s*(.+)\s*$/m) {
                        $result{project} = $2;
                    }elsif ($line =~ m/^#OAR\s+(--hold)\s*$/m) {
                        $result{hold} = 1;
                    }elsif ($line =~ m/^#OAR\s+(-a|--anterior)\s*(\d+)\s*$/m) {
                        push(@{$result{anterior}}, $2);
                    }elsif ($line =~ m/^#OAR\s+(--signal)\s*(\d+)\s*$/m) {
                        $result{signal} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-O|--stdout)\s*(.+)\s*$/m) {
                        $result{stdout} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-E|--stderr)\s*(.+)\s*$/m) {
                        $result{stderr} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-k|--use-job-key)\s*$/m) {
                        $result{usejobkey} = 1;
                    }elsif ($line =~ m/^#OAR\s+(--import-job-key-inline-priv)\s*(.+)\s*$/m) {
                        $result{importjobkeyinlinepriv} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-i|--import-job-key-from-file)\s*(.+)\s*$/m) {
                        $result{importjobkeyfromfile} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-e|--export-job-key-to-file)\s*(.+)\s*$/m) {
                        $result{exportjobkeytofile} = $2;
                    }elsif ($line =~ m/^#OAR\s+(-s|--stagein)\s*(.+)\s*$/m) {
                        $result{stagein} = $2;
                    }elsif ($line =~ m/^#OAR\s+(--stagein-md5sum)\s*(.+)\s*$/m) {
                        $result{stageinmd5sum} = $2;
                    }elsif ($line =~ m/^#OAR\s+(--array)\s*(\d+)\s*$/m) {
                        $result{array} = $2;
                    }elsif ($line =~ m/^#OAR\s+(--array-param-file)\s*(.+)\s*$/m) {
                        $result{arrayparamfile} = $2;
                    }else{
                        warn("/!\\ Not able to scan file line: $line");
                        $error++;
                    }
                    chop($line);
                    $Initial_request_string .= "; $line";
                }
            }
        }
        if (!close(FILE)){
            warn("[ERROR] Cannot open the file $file. Check if it is readable by everybody (744).\n");
            exit(12);
        }
    }else{
        warn("[ERROR] Cannot execute: oardodo cat $file\n");
        exit(12);
    }
    if ($error > 0){
        warn("[ERROR] $error error(s) encountered while parsing the file $file.\n");
        exit(12);
    }
	$result{initial_request} = $Initial_request_string;
    return(\%result);
}

sub read_array_param_file($){
    my $array_param_file = shift;
    my @array_params;
    if (open(PARAMETER_FILE, "oardodo cat $array_param_file |")){
        while(<PARAMETER_FILE>) {
            s/#.*//; # ignore comments by erasing them
            next if /^\s*$/;  # skip blank lines
            chomp;  # remove trailing newline characters
            push (@array_params, $_);
        }
        if (!close(PARAMETER_FILE)){
            warn("[ERROR] Cannot open the parameter file $array_param_file.\n");
            exit(12);
        }
    }else{
        warn("[ERROR] Cannot execute: oardodo cat $array_param_file\n");
        exit(12);
    }
    return \@array_params;
}

1;
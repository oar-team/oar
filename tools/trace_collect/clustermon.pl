#!/usr/bin/perl
use Getopt::Long;
use Getopt::Long;
use strict;

#important files and fields to capture
#######/proc/pid/stat#################
# field 10 number of minor faults
# field 12 number of major faults
# filed 22 virtual memory size    (better to take this field  form  status file)
# field 23 residen set memory size ( better to take  this field  form status file)
######/proc/pid/status################
#VmPeak   peak virtual memory size
#VmSize   total program size
#VmRSS    size of memory portions
#VmSwap   size of swap usage (the number of referred swapents)
#####/proc/pid/statm ##########
#Field    Content
#1-size     total program size (pages)		
#2-resident size of memory portions (pages)	(same as VmRSS in status)
#3-shared   number of pages that are shared	(i.e. backed by a file)
#####/proc/pid/io #######
#rchar  - bytes read
#wchar  - byres written
#syscr  - number of read syscalls
#syscw  - number of write syscalls
#read_bytes - number of bytes caused by this process to read from underlying storage
#write_bytes - number of bytes caused by this process to written from underlying storage

#mesauring the %CPU Utilization
#ps -p PID -o "pcpu" | sed  '/%CPU/d' gives us the CPU %  per pid

#####NETWORK################
#####file  /proc/PID/net/dev
##Format################
#Interface, Receive : bytes,  packets,
#           Trasmit : bytes,  packets,


############NFS FILE SYSTEM #############
#cat /proc/$pid/mountstats | grep WRITE | awk '{print $5}'  bytes writes to a NFS system
#cat /proc/$pid/mountstats | sed -n '/READ$/p' | awk '{print $5}'
#######################################################################################################

###File Format  ##############
#timestamp
#OAR_JOB_ID
#PID
#command line
#number of minor faults
#number of major faults
#VmPeak   peak virtual memory size
#VmSize   total program size
#VmRSS    size of memory portions
#VmSwap   size of swap usage (the number of referred swapents)
#size     total program size (pages)		
#resident size of memory portions (pages)	(same as VmRSS in status)
#shared   number of pages that are shared	(i.e. backed by a file)
#rchar  - bytes read
#wchar  - byres written
#syscr  - number of read syscalls
#syscw  - number of write syscalls
#read_bytes - number of bytes caused by this process to read from underlying storage
#write_bytes - number of bytes caused by this process to written from           underlying storage
#%CPU Utilization
#Receive : bytes
#Trasmit : bytes

###################################################################################################
###### Parameters ###############################
#Trace directory 
#CPUSET directory


my @task;
my $dir="";
my $conf_file="clustermon.conf"; ##### default config file
my $log_file="/var/log/clustermon.log"; 
my $cmdline;
my %params=();
my $pid;
my $numtask;
my $jobid;
my $hostname;
my $vmswap;
my $vmsize;
my $vmpeak;
my $vmrss;
my $syscr;
my $charread;
my $charwrite;
my $interface;
my $cpu;
my $syscw;
my @dirs;
my $timestamp;
my $read_bytes;
my $write_bytes;
my $isolated;

sub usage() {
	print <<EOS;
Usage: $0 -f confile
Options are:
 -f,  configuration file 
EOS
}

use sigtrap 'handler' => \&cleanAndExit, 'INT', 'ABRT', 'QUIT', 'TERM';

sub cleanAndExit(){

    print "Cleaning up and  exiting\n";
    exit(1);
}

sub readconf
{
	open CONF,$conf_file or  die "Cannot open configuration file \n";
	%params=();
	while(<CONF>)
	{
		chomp;
		my($key,$val)=split(/:/,$_);
		$val =~ s/^\s+//; ##getting rid of possble blank spaces at the begining of the variable
		$params{$key}=$val;
	}
	close(CONF);
}

sub writelog($)
{
	my $message=shift();
	my $timelog=time();
	open (LOG, ">>$log_file");
	print LOG "$timelog   $message \n";
	close(LOG);
	
} 
sub readtask($)
{
          my @taskread=();
	  my $dirtask=shift();
          open TASKS, "$params{CPUSETDIR}$dirtask/tasks " or  die "Cannot open file \n";
	  #print "/dev/cpuset/oar/$dir/tasks \n";
	 
         while ($numtask=<TASKS>) { 
                  chomp($numtask);
		  #Getting ride of the OAR tasks
		  #Testing
		  
		  my $jobid=(split(/_/,$dirtask))[1];
		  my $oartask2;my $oartask3;
		  if( -e "/var/lib/oar/pid_of_oarexec_for_jobId_$jobid"){$oartask2=`cat /var/lib/oar/pid_of_oarexec_for_jobId_$jobid`;}
		  if( -e "/var/lib/oar/oarsub_connections_$jobid"){chomp($oartask3=`cat /var/lib/oar/oarsub_connections_$jobid`);}
		  my $processname=`ps -p $numtask |  sed -n 2p | awk '{print \$4}'`;
		  chomp(my $oartask1=`ps ax | grep $numtask | sed '2 d' | awk '{print \$6}'`);
		  if($oartask1 !~ /.*oar\@notty.+/ && $oartask2 !~ $numtask && $oartask3 !~ $numtask && $processname ne "" ){push(@taskread,$numtask);}
                
          }
          close (TASKS);
	  return(@taskread);
}


Getopt::Long::Configure("gnu_getopt");
GetOptions("f=s" =>\$conf_file);

#Start 
#Reading configuration file

readconf;
#getting hostname
chomp($hostname=`hostname `);

# attempt to create TRACEDIR if it doesn't exist
if (!-d $params{TRACEDIR}) { mkdir $params{TRACEDIR} or die "Unable to create $params{TRACEDIR}" ;}
system("chown","oar","$params{TRACEDIR}");	

for (;;){
# Getting directories
  my $temp; #### to keep the directories ####
  if( -d  $params{CPUSETDIR}){ $temp=`ls $params{CPUSETDIR} | grep -E '[0-9]\$'`;}
  else { writelog( "Directory CPUSET does not exist ");}
  @dirs=();
  foreach $dir (split(/\n/,$temp)){push(@dirs,$dir);}
  #print " dirs: @dirs \n";
  if(@dirs)
  {
	$isolated=0;
	#verifying if there are more than one job in the machine
	if(@dirs>1){$isolated=1;}
    	#reading PID
    	foreach $dir (@dirs)
    	{  
      		#print "#############################################\n";
      		@task=readtask($dir);
      		#print "#############################################\n";
      		foreach $pid (@task){
			
			if( -d "/proc/$pid"){
				#Getting time
				$timestamp=time();
	                	#getting the OAR JOB ID	
      	                	my  $oarjobid=(split(/_/,$dir))[1];
				
				#Open the trace file
				open (TRACE, ">>$params{TRACEDIR}trace-$hostname-$oarjobid.log");
				
				#Setting permission for user oar
				system("chown","oar","$params{TRACEDIR}trace-$hostname-$oarjobid.log");		
				
				## getting the cmdline
				$cmdline=`ps -p $pid | sed -n 2p | awk '{print \$4}'`;
				$cmdline =~ s/\n//;
				$cmdline=substr($cmdline,0,15); ###Adjusting it to a length of 15 characters
				
				##reading /proc/pid/stat file ####
      				my $stat=`cat /proc/$pid/stat `;
      				my $minorfaults=(split(/ /,$stat))[9];
      				my $majorfaults=(split(/ /,$stat))[11];
      				
				## reading /proc/pid/status file ###
      				chomp($vmpeak=`cat /proc/$pid/status | sed -n '/VmPeak/p'`);
      				$vmpeak=(split(/  */,$vmpeak))[1];
      				chomp($vmsize=`cat /proc/$pid/status | sed -n '/VmSize/p'`);
      				$vmsize=(split(/  */,$vmsize))[1];
      				chomp($vmrss=`cat /proc/$pid/status | sed -n '/VmRSS/p'`);
      				$vmrss=(split(/  */,$vmrss))[1];
      				chomp($vmswap=`cat /proc/$pid/status | sed -n '/VmSwap/p'`);
      				my $vmswap=(split(/  */,$vmswap))[1];
				if($vmswap eq ""){ $vmswap=0;}
      				
				###reading /proc/pid/statm file ##
      				my $statm=`cat /proc/$pid/statm `;
      				my $msize=(split(/ /,$statm))[0];
      				my $mresident=(split(/ /,$statm))[1];
      				my $mshared=(split(/ /,$statm))[2];
      				
				###reading /proc/pid/io file #######
       				my $iostatus=`cat /proc/$pid/io `;
      				chomp($charread=(split(/\n/,$iostatus))[0]);
     				$charread=(split(/ /,$charread))[1];
      				chomp($charwrite=(split(/\n/,$iostatus))[1]);
      				$charwrite=(split(/ /,$charwrite))[1];
      				chomp($syscr=(split(/\n/,$iostatus))[2]);
      				$syscr=(split(/ /,$syscr))[1];
      				chomp($syscw=(split(/\n/,$iostatus))[3]);
      				$syscw=(split(/ /,$syscw))[1];
      				chomp($read_bytes=(split(/\n/,$iostatus))[4]);
				$read_bytes=(split(/ /,$read_bytes))[1];
				chomp($write_bytes=(split(/\n/,$iostatus))[5]);
                                $write_bytes=(split(/ /,$write_bytes))[1];
      				
				### getting the CPU % used by the process ####
      				chomp($cpu=`ps -p $pid -o "pcpu" | sed  '/CPU/d'`);
      				
				##### Network information /proc/PID/net/dev ####
				my $network=`cat /proc/$pid/net/dev`;#####testing code
      				my $recvtotal=0; my $recv;
      				my $sendtotal=0; my $send;
				foreach $interface (split(/\n/,$network)){
					if ($interface =~ /^\s+(\w+):\s*(\d+)\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+\d+\s+(\d+)/){
                				$recv=$2;
                				$send=$3;
					}
					$recvtotal=sprintf("%d",$recv)+$recvtotal;
					$sendtotal=sprintf("%d",$send)+$sendtotal;
            			}
				#printing information into file
				print TRACE "$timestamp $oarjobid $pid $cmdline $minorfaults $majorfaults $vmpeak $vmsize $vmrss $vmswap $msize $mresident $mshared $charread $charwrite $syscr $syscw $read_bytes $write_bytes $cpu $recvtotal $sendtotal \n"; 
				if($isolated==1){print TRACE "Warning: There are more than one Job in the machine \n";}
				}
   			}	
    }
  }
    close(TRACE);
    sleep(60);
}
 


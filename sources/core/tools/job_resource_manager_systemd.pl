# The job_resource_manager_cgroups script is a perl script that oar server
# DEploys on nodes to manage cpusets, users, job keys, ...
#
# In this script some cgroup Linux features are incorporated:
#     - [cpuset]  Restrict the job processes to use only the reserved cores;
#                 And restrict the allowed memory nodes to those directly
#                 attached to the cores (see the command "numactl -H")
#     - [cpu]     Nothing is done with this cgroup feature. By default each
#                 cgroup have cpu.shares=1024 (no priority)
#     - [cpuacct] Allow to have an accounting of the cpu times used by the
#                 job processes
#     - [freezer] Permit to suspend or resume the job processes.
#                 This is used by the suspend/resume of OAR (oarhold/oarresume)
#     - [memory]  Permit to restrict the amount of RAM that can be used by the
#                 job processes (ratio of job_nb_cores / total_nb_cores).
#                 This is useful for OOM problems (kill only tasks inside the
#                 cgroup where OOM occurs)
#                 DISABLED by default: there are maybe some performance issues
#                 (need to do some benchmarks)
#                 You can ENABLE this feature by putting 'my $Enable_mem_cg =
#                 "YES";' in the following code
#     - [devices] Allow or deny the access of devices for each job processes
#                 (By default every devices are allowed)
#                 You can ENABLE this feature to manage NVIDIA GPUs by putting
#                 'my $Enable_devices_cg = "YES";' in the following code.
#                 Also there must be a resource property named 'gpudevice'
#                 configured. This property must contain the GPU id which is
#                 allowed to be used (id on the compute node).
#     - [blkio]   Put an IO share corresponding to the ratio between reserved
#                 cores and the number of the node (this is disabled by default
#                 due to bad behaviour seen. More tests have to be done)
#                 There are some interesting accounting data available.
#                 You can ENABLE this feature by putting 'my $Enable_blkio_cg =
#                 "YES";' in the following code
#     - [net_cls] Tag each network packet from processes of this job with the
#                 class id = $OAR_JOB_ID.
#                 You can ENABLE this feature by putting 'my $Enable_net_cls_cg
#                 = "YES";' in the following code.
#     - [perf_event] You can ENABLE this feature by putting
#                 'my $Enable_perf_event_cg = "YES";' in the following code.
#     - [max_uptime] You can set '$max_uptime = <seconds>' to automaticaly
#                 reboot the node at the end of the last job past this uptime
#     - [systemd] You can ENABLE systemd support, which includes cgroupv2
#                 support. When activated, the cpuset code is disabled and
#                 replaced by systemd calls. To enable it, you need to create
#                 an empty file '/etc/oar/use_systemd' on the nodes to be 
#                 managed by systemd, or set-up $Enable_systemd = "YES" for
#                 using systemd by default on every nodes.
# Usage:
# This script is deployed from the server and executed as oar on the nodes
# ARGV[0] can have two different values:
#     - "init": then this script must create the right cpuset and assign
#                 corresponding cpus
#     - "clean": then this script must kill all processes in the cpuset and
#                 clean the cpuset structure

# TAKTUK_HOSTNAME environment variable must be defined and must be a key
# of the transfered hash table ($Cpuset variable).
use strict;
use warnings;
use Fcntl ':flock';

sub exit_myself($$);
sub print_log($$);
sub system_with_log($);

###############################################################################
# Script configuration start
###############################################################################
# Put YES if you want to use the memory cgroup
my $Enable_mem_cg = "YES";
# Put YES if you want to use the device cgroup (supports nvidia devices only for now)
my $Enable_devices_cg = "YES";
# Put YES if you want to use the blkio cgroup
my $Enable_blkio_cg = "NO";
# Put YES if you want to use the net_cls cgroup
my $Enable_net_cls_cg = "NO";
# Put YES if you want to use the perf_event cgroup
my $Enable_perf_event_cg = "NO";
# Set which memory nodes should be given to any job in the cpuset cgroup
# "all": all the memory nodes, even if the cpu which the memory node is attached to is not in the job
# "cpu": only the memory nodes associated to cpus which are in the job
my $Cpuset_cg_mem_nodes = "cpu";
# Where the OS mounts by itself the cgroups
my $OS_cgroups_path = "/sys/fs/cgroup";
# Directories where files of the job user will be deleted after the end of the
# job if there is not other running job of the same user on the node
my @Tmp_dir_to_clear = ('/tmp/.','/dev/shm/.','/var/tmp/.');
# SSD trim command path
my $Fstrim_cmd = "/sbin/fstrim";
# Groups location for OAR, if not mounted by the system
my $Cgroup_mount_point = "/dev/oar_cgroups";
# Directory where the cgroup mount points are linked to. Useful to have each
# cgroups in the same place with the same hierarchy.
my $Cgroup_directory_collection_links = "/dev/oar_cgroups_links";
# Max uptime for automatic reboot (disabled if 0)
my $max_uptime = 259200;
#my $max_uptime = 600;
my $Enable_systemd = "NO";
if (-e "/etc/oar/use_systemd") {
  $Enable_systemd = "YES";
}
###############################################################################
# Script configuration end
###############################################################################


my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Cpuset_lock_file = "$ENV{HOME}/cpuset.lock.";
my $Cpuset;
# Retrieve parameters from STDIN in the "Cpuset" structure which looks like:
# $Cpuset = {
#               job_id => id of the corresponding job,
#               name => "cpuset name",
#               cpuset_path => "relative path in the cpuset FS",
#               nodes => hostname => [array with the content of the database cpuset field],
#               ssh_keys => {
#                               public => {
#                                           file_name => "~oar/.ssh/authorized_keys",
#                                           key => "public key content",
#                                         },
#                               private => {
#                                           file_name => "directory where to store the private key",
#                                           key => "private key content",
#                                          },
#                           },
#               oar_tmp_directory => "path to the temp directory",
#               user => "user name",
#               job_user => "job user",
#               types => {hashtable with job types as keys},
#               resources => [ {property_name => value}, ],
#               node_file_db_fields => NODE_FILE_DB_FIELD,
#               node_file_db_fields_distinct_values => NODE_FILE_DB_FIELD_DISTINCT_VALUES,
#               array_id => job array id,
#               array_index => job index in the array,
#               stdout_file => stdout file name,
#               stderr_file => stderr file name,
#               launching_directory => launching directory,
#               job_name => job name,
#               walltime_seconds => job walltime in seconds,
#               walltime => job walltime,
#               project => job project name,
#               log_level => debug level number,
#           }

# Compute uptime
my $uptime = 0;
open UPTIME, "/proc/uptime" or die "Couldn't open /proc/uptime!";
($uptime, my $junk)=split(/\./, <UPTIME>);
close UPTIME;

my $Log_level;
my $tmp = "";
while (<STDIN>){
  $tmp .= $_;
}
$Cpuset = eval($tmp);

if (!defined($Cpuset->{log_level})){
  exit_myself(2,"Bad SSH hashtable transfered");
}
$Log_level = $Cpuset->{log_level};

# Features override per node
if (-e '/etc/oar/exclude_from_mem_cg') {
  $Enable_mem_cg = "NO";
  print_log(3,"File /etc/oar/exclude_from_mem_cg found. Force disabled mem cgroup.");
}
if (-e '/etc/oar/exclude_from_devices_isolation') {
  $Enable_devices_cg = "NO";
  print_log(3,"File /etc/oar/exclude_from_devices_isolation found. Force disabled GPU isolation.");
}
if (-e "/etc/oar/disable_numa_nodes") {
  $Cpuset_cg_mem_nodes = "all";
  print_log(3,"File /etc/oar/disable_numa_nodes found: all numa nodes will be allowed.");
}

my $Cpuset_path_job;
my @Cpuset_cpus;
my $Systemd_prefix="oar.";
my $Oardocker_node_cg_path = "";
# Get the data structure only for this node
if (defined($Cpuset->{cpuset_path})){
  if (-e $OS_cgroups_path.'/cpuset/oardocker') {
    # We are in oardocker, set the oardocker_node_path to /oardocker/<node_name>
    $Oardocker_node_cg_path = "/oardocker/$ENV{TAKTUK_HOSTNAME}";
    print_log(3,"Oardocker_node_cg_path=$Oardocker_node_cg_path");
  }
  $Cpuset_path_job = $Cpuset->{cpuset_path}.'/'.$Cpuset->{name};
  foreach my $l (@{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}}){
    push(@Cpuset_cpus, split(/[,\s]+/, $l));
  }
}

print_log(3,"$ARGV[0]");


###############################################################################
# Node initialization: run on all the nodes of the job before the job starts
###############################################################################

if ($ARGV[0] eq "init"){

  ### Initialize cpuset or systemd slice for this node ###

  # First, create the tmp oar directory
  if (!(((-d $Cpuset->{oar_tmp_directory}) and (-O $Cpuset->{oar_tmp_directory})) or (mkdir($Cpuset->{oar_tmp_directory})))){
    exit_myself(13,"Directory $Cpuset->{oar_tmp_directory} does not exist and cannot be created");
  }

  if (defined($Cpuset_path_job)){

    # SYSTEMD
    if ($Enable_systemd eq "YES") {
      # Using systemd, no cpuset init required
      # 
      print_log(3,"Using systemd");
      # Replace "-" and "." from cpuset name as systemd interprets them
      $Cpuset->{name}=~ s/\-/_/g;
      $Cpuset->{name}=~ s/\./_/g;
      $Cpuset->{name}=$Systemd_prefix.$Cpuset->{name};

    # CGROUPS V1
    }else{
      if (open(LOCKFILE,"> $Cpuset->{oar_tmp_directory}/job_manager_lock_file")){
        flock(LOCKFILE,LOCK_EX) or exit_myself(17,"flock failed: $!");
        if (!(-r $Cgroup_directory_collection_links.'/cpuset/tasks')){
          my @cgroup_list = ("cpuset","cpu","cpuacct","devices","freezer");
          push(@cgroup_list, "memory") if ($Enable_mem_cg eq "YES");
          push(@cgroup_list, "blkio") if ($Enable_blkio_cg eq "YES");
          push(@cgroup_list, "net_cls") if ($Enable_net_cls_cg eq "YES");
          push(@cgroup_list, "perf_event") if ($Enable_perf_event_cg eq "YES");
          if (!(-r $OS_cgroups_path.'/cpuset/tasks')){
            system_with_log('set -e
              oardodo mkdir -p '.$Cgroup_mount_point.'
              oardodo mount -t cgroup -o '.join(',',@cgroup_list).' none '.$Cgroup_mount_point.'
              oardodo rm -f /dev/cpuset
              oardodo ln -s '.$Cgroup_mount_point.' /dev/cpuset
              oardodo mkdir -p '.$Cgroup_directory_collection_links.'
              for cg in '.join(' ',@cgroup_list).'; do
              oardodo ln -s '.$Cgroup_mount_point.' '.$Cgroup_directory_collection_links.'/$cg
              done')
              and exit_myself(4,"Failed to mount cgroup pseudo filesystem");
          }else{
            # Cgroups already mounted by the OS
            system_with_log('set -e
              oardodo rm -f /dev/cpuset
              oardodo ln -s '.$OS_cgroups_path.'/cpuset'.$Oardocker_node_cg_path.' /dev/cpuset
              oardodo mkdir -p '.$Cgroup_directory_collection_links.'
              for cg in '.join(' ',@cgroup_list).'; do
              oardodo ln -s '.$OS_cgroups_path.'/$cg'.$Oardocker_node_cg_path.' '.$Cgroup_directory_collection_links.'/$cg
              done')
              and exit_myself(4,"Failed to link existing OS cgroup pseudo filesystem");
          }
        }
        if (!(-d $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path})){
          # Populate default oar cgroup
          system_with_log('set -e
            for d in '.$Cgroup_directory_collection_links.'/*; do
            oardodo mkdir -p $d/'.$Cpuset->{cpuset_path}.'
            oardodo chown -R oar $d/'.$Cpuset->{cpuset_path}.'
            /bin/echo 0 | cat > $d/'.$Cpuset->{cpuset_path}.'/notify_on_release
            done
            /bin/echo 0 | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpu_exclusive
            cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.mems > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.mems
            cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.cpus > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/cpuset.cpus')
            and exit_myself(4,"Failed to create cgroup $Cpuset->{cpuset_path}");
          if ($Enable_blkio_cg eq "YES") {
            system_with_log('/bin/echo 1000 | cat > '.$Cgroup_directory_collection_links.'/blkio/'.$Cpuset->{cpuset_path}.'/blkio.weight')
              and exit_myself(4,"Failed to create cgroup $Cpuset->{cpuset_path}");
          }
        }
        flock(LOCKFILE,LOCK_UN) or exit_myself(17,"flock failed: $!");
        close(LOCKFILE);
      }else{
        exit_myself(16,"Failed to open or create $Cpuset->{oar_tmp_directory}/job_manager_lock_file");
      }
    }

    ### Cgroup or systemd slice creation ###

    # Be careful with the physical_package_id. Is it corresponding to the memory bank?
    # Locking around the creation of the cpuset for that user, to prevent race condition during the dirty-user-based cleanup
    if (open(LOCK,">", $Cpuset_lock_file.$Cpuset->{user})){
      flock(LOCK,LOCK_EX) or die "flock failed: $!\n";
      # @Cpuset_cpus is an array of string containing either "1" or "1,17,33,49" if multiple logicial cpus / threads
      # are set in the cpuset field of the OAR DB (but not interval, e.g. '1-3').
      # The cpuset.cpus special file can be set using an unorder, redondant list of comma separated values, possibly
      # also including intervals (e.g. the thread siblings list could be '1-3').
      # No need to sort or transform intervals, e.g. "1,5-8,2,6" is ok. Retrieving the actual content of the file
      # after setting it will give "1-2,5-8"
      my $job_cpuset_cpus=join(",",@Cpuset_cpus);
      if (exists($Cpuset->{'compute_thread_siblings'}) and lc($Cpuset->{'compute_thread_siblings'}) eq "yes") {
        # If COMPUTE_THREAD_SIBLINGS="yes" in oar.conf, that means that the OAR DB has not info about the
        # HT threads siblings, so we have compute it here.
        my $job_cpuset_cpus=system_with_log('for i in '.join(" ", map {s/,/ /gr} @Cpuset_cpus).'; do cat /sys/devices/system/cpu/cpu$i/topology/thread_siblings_list; done | paste -sd, -');
      }

      # SYSTEMD
      if ($Enable_systemd eq "YES") {

        # Create transcient systemd slice and set properties
        print_log(3,"Creating ".$Cpuset->{name}.".slice transcient systemd slice");
        system_with_log('oardodo systemd-run --uid='.$Cpuset->{user}.' --slice '.$Cpuset->{name}.' --unit '.$Cpuset->{name}.' -p Delegate=yes sleep infinity')
          and exit_myself(5,"Failed to create transcient systemd slice $Cpuset->{name}");
        system_with_log('oardodo systemctl set-property '.$Cpuset->{name}.'.slice \
                           AllowedCPUs="'.$job_cpuset_cpus.'" \
                           AllowedMemoryNodes=""')
          and exit_myself(5,"Failed to set cpu properties of systemd slice $Cpuset->{name}");

        # Setting numa nodes property
        if ($Cpuset_cg_mem_nodes eq "cpu"){
          print_log(3,"Setting memory nodes of systemd slice $Cpuset->{name}");
          system_with_log('set -e
            MEM=
            for c in '."@Cpuset_cpus".'; do
              for n in /sys/devices/system/node/node* ; do
              if [ -r "$n/cpu$c" ]; then
                MEM=$(basename $n | sed s/node//g),$MEM
              fi
              done
            done
            oardodo systemctl set-property '.$Cpuset->{name}.'.slice \
              AllowedMemoryNodes="$MEM"')
          and exit_myself(5,"Failed to feed the mem nodes of systemd slice $Cpuset->{name}");
        }
 
      # CGROUP V1
      }else{
        my $job_cpuset_cpus_cmd = '/bin/echo '.$job_cpuset_cpus.' | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.cpus';
        system_with_log('set -e
          for d in '.$Cgroup_directory_collection_links.'/*; do
            oardodo mkdir -p $d/'.$Cpuset_path_job.'
            oardodo chown -R oar $d/'.$Cpuset_path_job.'
            /bin/echo 0 | cat > $d/'.$Cpuset_path_job.'/notify_on_release
          done
          /bin/echo 0 | cat > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.cpu_exclusive
          '.$job_cpuset_cpus_cmd)
          and exit_myself(5,"Failed to create and feed the cpuset cpus $Cpuset_path_job");
        if ($Cpuset_cg_mem_nodes eq "all"){
          system_with_log('cat '.$Cgroup_directory_collection_links.'/cpuset/cpuset.mems > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.mems')
            and exit_myself(5,"Failed to feed the mem nodes to cpuset $Cpuset_path_job");
        } else {
          system_with_log('set -e
            for d in '.$Cgroup_directory_collection_links.'/*; do
              MEM=
              for c in '."@Cpuset_cpus".'; do
                for n in /sys/devices/system/node/node* ; do
                if [ -r "$n/cpu$c" ]; then
                  MEM=$(basename $n | sed s/node//g),$MEM
                fi
                done
              done
            done
            echo $MEM > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/cpuset.mems')
          and exit_myself(5,"Failed to feed the mem nodes to cpuset $Cpuset_path_job");
        }
      }
      flock(LOCK,LOCK_UN) or die "flock failed: $!\n";
      close(LOCK);
    } else {
      exit_myself(16,"[cpuset_manager] Error opening $Cpuset_lock_file");
    }

    ### Special features ###

    my $node_cpus_file=$Cgroup_directory_collection_links."/cpuset/cpuset.cpus";
    my $job_cpus_file=$Cgroup_directory_collection_links."/cpuset/".$Cpuset_path_job."/cpuset.cpus";
    # Set cgroups cpus file location for the systemd feature
    if ($Enable_systemd eq "YES") {
      # cgroup v2
      $node_cpus_file=$OS_cgroups_path.'/cpuset.cpus.effective';
      $job_cpus_file=$OS_cgroups_path.'/'.$Cpuset->{name}.'.slice/cpuset.cpus';
      # cgroup v1
      if (not -e $job_cpus_file) {
        print_log(2,"Warning: cgroups v2 files not found, guessing cgroup v1 hierarchy...");
        $node_cpus_file=$OS_cgroups_path.'/cpuset/cpuset.cpus';
        $job_cpus_file=$OS_cgroups_path.'/systemd/'.$Cpuset->{name}.'.slice/cpuset.cpus';
      }
    }

    # Compute the actual job cpus (@Cpuset_cpus may not have the HT included, depending on the OAR resources definiton)
    my @job_cpus;
      if (open(CPUS, $job_cpus_file)){
      my $str = <CPUS>;
      chop($str);
      $str =~ s/\-/\.\./g;
      @job_cpus = eval($str);
      close(CPUS);
    }else{
      exit_myself(5,"Failed to retrieve the cpu list of the job $job_cpus_file");
    }

    # Get all the cpus of the node
    my @node_cpus;
    if (open(CPUS, $node_cpus_file)){
      my $str = <CPUS>;
      chop($str);
      $str =~ s/\-/\.\./g;
      @node_cpus = eval($str);
      close(CPUS);
    }else{
      exit_myself(5,"Failed to retrieve the cpu list of the node $node_cpus_file");
    }

    # Tag network packets from processes of this job
    if ($Enable_net_cls_cg eq "YES") {
      # SYSTEMD                      
      if ($Enable_systemd eq "YES") {
        print_log(2,"No support for network packets tagging with systemd feature");
      # CGROUP v1
      }else{
        system_with_log( '/bin/echo '.$Cpuset->{job_id}.' | cat > '.$Cgroup_directory_collection_links.'/net_cls/'.$Cpuset_path_job.'/net_cls.classid')
          and exit_myself(5,"Failed to tag network packets of the cgroup $Cpuset_path_job");
      }
    }

    # Put a share for IO disk corresponding of the ratio between the number
    # of cpus of this cgroup and the number of cpus of the node
    if ($Enable_blkio_cg eq "YES") {
      # SYSTEMD                      
      if ($Enable_systemd eq "YES") {
        # Not yet tested! (check if it works and if it has not the problems of the TODO bellow with cgroup v1)
        my $IO_ratio = sprintf("%.0f",(($#job_cpus + 1) / ($#node_cpus + 1) * 10000)) ;
        system_with_log('oardodo systemctl set-property '.$Cpuset->{name}.'.slice \           
                         IOWeight='.$IO_ratio)                                            
          and exit_myself(5,"Failed to set IOweight of systemd slice $Cpuset->{name}"); 
      # CGROUP v1
      }else{
        my $IO_ratio = sprintf("%.0f",(($#job_cpus + 1) / ($#node_cpus + 1) * 1000)) ;
        # TODO: Need to do more tests to validate so remove this feature
        #       Some values are not working when echoing, force value to 1000 for now.
        $IO_ratio = 1000;
        system_with_log( '/bin/echo '.$IO_ratio.' | cat > '.$Cgroup_directory_collection_links.'/blkio/'.$Cpuset_path_job.'/blkio.weight')
          and exit_myself(5,"Failed to set the blkio.weight to $IO_ratio");
      }
    }
 

    # Manage GPU devices
    if ($Enable_devices_cg eq "YES"){

      opendir(my($dh), "/dev") or exit_myself(5,"Failed to open /dev directory for Enable_devices_cg feature");

      # Get the list of NVIDIA or AMD GPU devices
      my $nvidia_gpus=0; # nvidia flag
      my @devices = ();
      my @other_devices = ();
      my @files = grep { /nvidia/ } readdir($dh);
      foreach (@files){
        if ($_ =~ /nvidia(\d+)/){
          $nvidia_gpus=1;
          print_log(3,"Found Nvidia device /dev/nvidia".$1);
          push (@devices, $1);
        }else{
          push (@other_devices, "/dev/".$_);
        }
      }

      # Get the list of AMD (or other types) GPU devices
      # if we don't get nvidia devices, we suppose that we have AMD devices
      my $amd_gpus=0; # AMD flag
      if ($nvidia_gpus == 0) {      
        @files = grep { /dev\/dri/ } readdir($dh);
        foreach (@files){
          if ($_ =~ /card(\d+)/){
            $amd_gpus=1;
            print_log(3,"Found GPU device /dev/dri/card".$1);
            push (@devices, $1);
          }else{
            push (@other_devices, "/dev/dri/".$_);
          }
        }
      }
      closedir($dh);


      # SYSTEMD                      
      if ($Enable_systemd eq "YES") {
        my $gpu_device_prefix = "";
        if ($nvidia_gpus == 1) {
          $gpu_device_prefix = "/dev/nvidia";
          push (@other_devices, "/dev/nvidia-caps/nvidia-cap1");
          push (@other_devices, "/dev/nvidia-caps/nvidia-cap2");
        }elsif ($amd_gpus == 1) {
          # Not tested!
          $gpu_device_prefix = "/dev/drm/card";
        }else{
          print_log(3,"No GPU devices found");
        }
        if ($nvidia_gpus == 1 or $amd_gpus == 1) { 
          my $systemd_devices="DevicePolicy=closed ";
          foreach my $r (@{$Cpuset->{'resources'}}){
            if (($r->{type} eq "default") and
              ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
              ($r->{'gpudevice'} ne '')
            ){
              @devices = grep { $_ ==  $r->{'gpudevice'} } @devices;
            }
          }
          foreach my $dev (@devices) {
            $systemd_devices.='DeviceAllow="'.$gpu_device_prefix.''.$dev.' rwm"'." ";
            print_log(3,"Allowing $gpu_device_prefix"."$dev device into systemd slice $Cpuset->{name}");
          }
          foreach my $dev (@other_devices) {
            $systemd_devices.='DeviceAllow="'.$dev.' rwm"'." ";
            print_log(3,"Allowing $dev device into systemd slice $Cpuset->{name}");
          }
          system_with_log('oardodo systemctl set-property '.$Cpuset->{name}.'.slice '.$systemd_devices)                                            
            and exit_myself(5,"Failed to set devices filtering of systemd slice $Cpuset->{name} : \"$systemd_devices\""); 
        }
 

      # CGROUP v1
      }else{
        # Nvidia GPU
       my @devices_deny=@devices;
       if ($#devices_deny > -1){
          # now remove from denied devices our reserved devices
          foreach my $r (@{$Cpuset->{'resources'}}){
            if (($r->{type} eq "default") and
              ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
              ($r->{'gpudevice'} ne '')
            ){
              @devices_deny = grep { $_ !=  $r->{'gpudevice'} } @devices_deny;
            }
          }
          print_log(3,"Deny NVIDIA GPUs: @devices_deny");
          my $devices_cgroup = $Cgroup_directory_collection_links."/devices/".$Cpuset_path_job."/devices.deny";
          foreach my $dev (@devices_deny){
            system_with_log("oardodo /bin/echo 'c 195:$dev rwm' > $devices_cgroup")
              and exit_myself(5,"Failed to set the devices.deny to c 195:$dev rwm");
          }
        }
        # Nvidia MIG
        my $have_nvidia=1;
        @devices_deny = ();
        opendir($dh, "/proc/driver/nvidia/capabilities") or $have_nvidia=0;
        if ($have_nvidia == 1){
          @files = grep { /gpu/ } readdir($dh);
          foreach (@files){
            if ($_ =~ /gpu(\d+)/){
              my $gpudev=$1;
              opendir(my($mdh), "/proc/driver/nvidia/capabilities/gpu$gpudev/mig");
              my @mfiles = grep { /gi/ } readdir($mdh);
              foreach (@mfiles){
                if ($_ =~ /gi(\d+)/){
                  push (@devices_deny, "$gpudev:$1")
                }
              }
              closedir($mdh);
            }
          }
          print_log(3,"MIGs list : @devices_deny");
          closedir($dh);
          if ($#devices_deny > -1){
            # now remove from denied migs our reserved migs
            foreach my $r (@{$Cpuset->{'resources'}}){
              if (($r->{type} eq "default") and
                ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
                ($r->{'migdevice'} ne '')
              ){
                @devices_deny = grep { $_ ne  $r->{'gpudevice'}.":".$r->{'migdevice'} } @devices_deny;
              }
            }
            print_log(3,"Deny NVIDIA MIGs: @devices_deny");
            my $devices_cgroup = $Cgroup_directory_collection_links."/devices/".$Cpuset_path_job."/devices.deny";
            foreach my $dev (@devices_deny){
              my ($gpu, $mig) = split /:/, $dev;
              open(my $fh, '<', "/proc/driver/nvidia/capabilities/gpu$gpu/mig/gi$mig/access") or exit_myself(5,"Failed to open /proc/driver/nvidia/capabilities/gpu$gpu/mig/gi$mig/access");
              my $major;
              my $minor;
              while(<$fh>){
                chomp;
                my ($key,$val) = split /: /, $_;
                if($key eq "DeviceFileMinor"){
                  $minor=$val;
                }
              }
              close($fh);
              open($fh, '<', "/proc/devices") or exit_myself(5,"Failed to open /proc/devices");
              while(<$fh>){
                chomp;
                if ($_ =~ / *(\d+) nvidia-caps$/){
                  $major=$1;
                }
              }
              close($fh);
              print_log(3,"oardodo /bin/echo 'c $major:$minor rwm' > $devices_cgroup");
              system_with_log("oardodo /bin/echo 'c $major:$minor rwm' > $devices_cgroup")
                and exit_myself(5,"Failed to set the MIG devices.deny to c $major:$minor rwm");
            }
          }
        } # End if ($have_nvidia == 1)

        # Other GPU
        if (opendir($dh, "/dev/dri")) {
          @devices_deny = ();
          @files = grep { /renderD/ } readdir($dh);
          foreach (@files){
            if ($_ =~ /renderD(\d+)/){
              push (@devices_deny, $1-128);
            }
          }
          closedir($dh);
          if ($#devices_deny > -1){
            # now remove from denied devices our reserved devices
            foreach my $r (@{$Cpuset->{'resources'}}){
              if (($r->{type} eq "default") and
                ($r->{network_address} eq "$ENV{TAKTUK_HOSTNAME}") and
                ($r->{'gpudevice'} ne '')
              ){
                @devices_deny = grep { $_ !=  $r->{'gpudevice'} } @devices_deny;
              }
            }
            print_log(3,"Deny other GPUs: @devices_deny");
            my $devices_cgroup = $Cgroup_directory_collection_links."/devices/".$Cpuset_path_job."/devices.deny";
            foreach my $dev (@devices_deny){
              system_with_log("oardodo /bin/echo 'c 226:$dev rwm' > $devices_cgroup")
                and exit_myself(5,"Failed to set the devices.deny to c 226:$dev rwm");
              my $renderdev = $dev + 128;
              system_with_log("oardodo /bin/echo 'c 226:$renderdev rwm' > $devices_cgroup")
                and exit_myself(5,"Failed to set the devices.deny to c 226:$renderdev rwm");
            }
          }
        }
      }
    } # if ($Enable_devices_cg eq "YES")


    # Assign the corresponding share of memory if memory cgroup enabled.
    if ($Enable_mem_cg eq "YES"){
      my $mem_global_kb;
      if (open(MEM, "/proc/meminfo")){
        while (my $line = <MEM>){
          if ($line =~ /^MemTotal:\s+(\d+)\skB$/){
            $mem_global_kb = $1 * 1024;
            last;
          }
        }
        close(MEM);
      }else{
        exit_myself(5,"Failed to retrieve the global memory from /proc/meminfo");
      }
      exit_myself(5,"Failed to parse /proc/meminfo to retrive MemTotal") if (!defined($mem_global_kb));
      my $mem_kb = sprintf("%.0f", (($#job_cpus + 1) / ($#node_cpus + 1) * $mem_global_kb));
 
     # SYSTEMD
      if ($Enable_systemd eq "YES") {
        print_log(2,"Warning: systemd is a work in progress, some features may be missing");
        system_with_log('oardodo systemctl set-property '.$Cpuset->{name}.'.slice MemoryMax='.$mem_kb.'K')                                            
          and exit_myself(5,"Failed to set MemoryMax of systemd slice $Cpuset->{name}: $mem_kb"."K"); 

      # CGROUPS V1
      }else{
        system_with_log('/bin/echo '.$mem_kb.' | cat > '.$Cgroup_directory_collection_links.'/memory/'.$Cpuset_path_job.'/memory.limit_in_bytes')
          and exit_myself(5,"Failed to set the memory.limit_in_bytes to $mem_kb");
      }

    } # End else ($Enable_mem_cg eq "YES")

    # Create file used in the user jobs (environment variables, node files, ...)
    ## Feed the node file
    my @tmp_res;
    my %tmp_already_there;
    foreach my $r (@{$Cpuset->{resources}}){
      if (($r->{$Cpuset->{node_file_db_fields}} ne "") and ($r->{type} eq "default")){
        if (($r->{$Cpuset->{node_file_db_fields_distinct_values}} ne "") and (!defined($tmp_already_there{$r->{$Cpuset->{node_file_db_fields_distinct_values}}}))){
          push(@tmp_res, $r->{$Cpuset->{node_file_db_fields}});
          $tmp_already_there{$r->{$Cpuset->{node_file_db_fields_distinct_values}}} = 1;
        }
      }
    }
    if (open(NODEFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}")){
      foreach my $f (sort(@tmp_res)){
        print(NODEFILE "$f\n") or exit_myself(19,"Failed to write in node file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
      }
      close(NODEFILE);
    }else{
      exit_myself(19,"Failed to create node file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
    }
    ## create resource set file
    if (open(RESFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources")){
      foreach my $r (@{$Cpuset->{resources}}){
        my $line = "";
        foreach my $p (keys(%{$r})){
          $r->{$p} = "" if (!defined($r->{$p}));
          $line .= " $p = '$r->{$p}' ,"
        }
        chop($line);
        print(RESFILE "$line\n") or exit_myself(19,"Failed to write in resource file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
      }
      close(RESFILE);
    }else{
      exit_myself(19,"Failed to create resource file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
    }
    ## Write environment file
    if (open(ENVFILE, "> $Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env")){
      my $job_name = "";
      $job_name = $Cpuset->{job_name} if defined($Cpuset->{job_name});
      my $filecontent = <<"EOF";
export OAR_JOBID='$Cpuset->{job_id}'
export OAR_ARRAYID='$Cpuset->{array_id}'
export OAR_ARRAYINDEX='$Cpuset->{array_index}'
export OAR_USER='$Cpuset->{user}'
export OAR_WORKDIR='$Cpuset->{launching_directory}'
export OAR_JOB_NAME='$job_name'
export OAR_PROJECT_NAME='$Cpuset->{project}'
export OAR_STDOUT='$Cpuset->{stdout_file}'
export OAR_STDERR='$Cpuset->{stderr_file}'
export OAR_FILE_NODES='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}'
export OAR_RESOURCE_PROPERTIES_FILE='$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources'
export OAR_JOB_WALLTIME='$Cpuset->{walltime}'
export OAR_JOB_WALLTIME_SECONDS='$Cpuset->{walltime_seconds}'
export OAR_NODEFILE=\$OAR_FILE_NODES
export OAR_NODE_FILE=\$OAR_FILE_NODES
export OAR_RESOURCE_FILE=\$OAR_RESOURCE_PROPERTIES_FILE
export OAR_O_WORKDIR=\$OAR_WORKDIR
export OAR_WORKING_DIRECTORY=\$OAR_WORKDIR
export OAR_JOB_ID=\$OAR_JOBID
export OAR_ARRAY_ID=\$OAR_ARRAYID
export OAR_ARRAY_INDEX=\$OAR_ARRAYINDEX
EOF
      print(ENVFILE "$filecontent") or exit_myself(19,"Failed to write in file ");
    }else{
      exit_myself(19,"Failed to create file ");
    }
  }

  # Copy ssh key files
  if ($Cpuset->{ssh_keys}->{private}->{key} ne ""){
    # private key
    if (open(PRIV, ">".$Cpuset->{ssh_keys}->{private}->{file_name})){
      chmod(0600,$Cpuset->{ssh_keys}->{private}->{file_name});
      if (!print(PRIV $Cpuset->{ssh_keys}->{private}->{key})){
        unlink($Cpuset->{ssh_keys}->{private}->{file_name});
        exit_myself(8,"Error writing $Cpuset->{ssh_keys}->{private}->{file_name}");
      }
      close(PRIV);
    }else{
      exit_myself(7,"Error opening $Cpuset->{ssh_keys}->{private}->{file_name}");
    }

    # public key
    if (open(PUB,"+<",$Cpuset->{ssh_keys}->{public}->{file_name})){
      flock(PUB,LOCK_EX) or exit_myself(17,"flock failed: $!");
      seek(PUB,0,0) or exit_myself(18,"seek failed: $!");
      my $out = "\n".$Cpuset->{ssh_keys}->{public}->{key}."\n";
      while (<PUB>){
        if ($_ =~ /environment=\"OAR_KEY=1\"/){
          # We are reading a OAR key
          $_ =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
          my $oar_key = $2;
          $Cpuset->{ssh_keys}->{public}->{key} =~ /(ssh-dss|ssh-rsa)\s+([^\s^\n]+)/;
          my $curr_key = $2;
          if ($curr_key eq $oar_key){
            exit_myself(13,"ERROR: the user has specified the same ssh key than used by the user oar");
          }
          $out .= $_;
        }elsif ($_ =~ /environment=\"OAR_CPUSET=([\w\/]+)\"/){
          # Remove from authorized keys outdated keys (typically after a reboot)
          if (-d "/dev/cpuset/$1"){
            $out .= $_;
          }
        }else{
          $out .= $_;
        }
      }
      if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))){
        exit_myself(9,"Error writing $Cpuset->{ssh_keys}->{public}->{file_name}");
      }
      flock(PUB,LOCK_UN) or exit_myself(17,"flock failed: $!");
      close(PUB);
    }else{
      unlink($Cpuset->{ssh_keys}->{private}->{file_name});
      exit_myself(10,"Error opening $Cpuset->{ssh_keys}->{public}->{file_name}");
    }
  }



###############################################################################
# Node cleaning: run on all the nodes of the job after the job ends
###############################################################################

}elsif ($ARGV[0] eq "clean"){
  # delete ssh key files
  if ($Cpuset->{ssh_keys}->{private}->{key} ne ""){
    # private key
    unlink($Cpuset->{ssh_keys}->{private}->{file_name});

    # public key
    if (open(PUB,"+<", $Cpuset->{ssh_keys}->{public}->{file_name})){
      flock(PUB,LOCK_EX) or exit_myself(17,"flock failed: $!");
      seek(PUB,0,0) or exit_myself(18,"seek failed: $!");
      #Change file on the fly
      my $out = "";
      while (<PUB>){
        if (($_ ne "\n") and ($_ ne $Cpuset->{ssh_keys}->{public}->{key})){
          $out .= $_;
        }
      }
      if (!(seek(PUB,0,0) and print(PUB $out) and truncate(PUB,tell(PUB)))){
        exit_myself(12,"Error changing $Cpuset->{ssh_keys}->{public}->{file_name}");
      }
      flock(PUB,LOCK_UN) or exit_myself(17,"flock failed: $!");
      close(PUB);
    }else{
      exit_myself(11,"Error opening $Cpuset->{ssh_keys}->{public}->{file_name}");
    }
  }

  # Kill tasks on this node

  # SYSTEMD
  if ($Enable_systemd eq "YES") {

    # Replace "-" and "." from cpuset name as systemd interprets them
    $Cpuset->{name}=~ s/\-/_/g;
    $Cpuset->{name}=~ s/\./_/g;
    $Cpuset->{name}=$Systemd_prefix.$Cpuset->{name};
    
    # Cleaning
    print_log(2,"Systemd cleaning...");

    # (disabled as it caused timeouts... need more test with frozen cgroups)
    #system_with_log('oardodo systemctl thaw '.$Cpuset->{name}.'.slice')
    #  and exit_myself(6,'Failed to thaw processes of '.$Cpuset->{name}.'.slice');

    system_with_log('oardodo systemctl kill -s 9 '.$Cpuset->{name}.'.slice')
      and exit_myself(6,'Failed to kill processes of '.$Cpuset->{name}.'.slice');

    system_with_log('oardodo systemctl stop '.$Cpuset->{name}.'.slice; sleep 5')
      and exit_myself(6,'Failed to stop '.$Cpuset->{name}.'.slice');

     # TODO: add a check of the slice to wait for it to be actualy inactive (and remove the sleep above)

  # CGROUPv1
  }elsif(defined($Cpuset_path_job)){
    system_with_log('echo THAWED > '.$Cgroup_directory_collection_links.'/freezer/'.$Cpuset_path_job.'/freezer.state
          for d in '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/* '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'; do
            if [ -d $d ]; then
              PROCESSES=$(cat $d/tasks)
              while [ "$PROCESSES" != "" ]; do
                oardodo kill -9 $PROCESSES > /dev/null 2>&1
                PROCESSES=$(cat $d/tasks)
              done
            fi
          done');
  }

  # Locking around the cleanup of the cpuset for that user, to prevent a creation to occure at the same time
  # which would allow race condition for the dirty-user-based clean-up mechanism
  if (open(LOCK,">", $Cpuset_lock_file.$Cpuset->{user})){
    flock(LOCK,LOCK_EX) or die "flock failed: $!\n";

    # Cgroup cleaning
    # SYSTEMD
    if ($Enable_systemd eq "YES") {
      # Systemd should already have cleaned the cgroups
    # CGROUPv1
    }elsif(defined($Cpuset_path_job)){
      system_with_log('if [ -w '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty ]; then
                             echo 0 > '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/memory.force_empty
                           fi
                           for d in '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'/* '.$Cgroup_directory_collection_links.'/cpuset/'.$Cpuset_path_job.'; do
                             if [ -d $d ]; then
                               [ -w $d/memory.force_empty ] && echo 0 > $d/memory.force_empty
                               while ! oardodo rmdir $d ; do
                                 cat $d/tasks | xargs -n1 ps -fh -p 1>&2
                                 echo retry in 1s... 1>&2
                                 sleep 1
                               done
                             fi
                           done
                           for d in '.$Cgroup_directory_collection_links.'/*/'.$Cpuset_path_job.'/* '.$Cgroup_directory_collection_links.'/*/'.$Cpuset_path_job.'; do
                             if [ -d $d ]; then
                               [ -w $d/memory.force_empty ] && echo 0 > $d/memory.force_empty
                               oardodo rmdir $d > /dev/null 2>&1
                             fi
                           done')
          # Uncomment this line if you want to use several network_address properties
          # which are the same physical computer (linux kernel)
          # and exit(0)
            and exit_myself(6,"Failed to delete the cpuset $Cpuset_path_job");
    }

    # dirty-user-based cleanup: do cleanup only if that is the last job of the user on that host.
    my @cpusets = ();
    my @other_cpusets = ();

    # Get the number of other jobs for the user and for others
    # SYSTEMD
    if ($Enable_systemd eq "YES") {                    
      @cpusets = system_with_log("systemctl list-units oar.".$Cpuset->{user}."_*.slice --plain --legend=0 --state=active");
      @other_cpusets = system_with_log("systemctl list-units oar.*.slice --plain --legend=0 --state=active");
    # CGROUPv1
    }elsif(defined($Cpuset_path_job)){
      if (opendir(DIR, $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/')) {
        @cpusets = grep { /^$Cpuset->{user}_\d+$/ } readdir(DIR);
        closedir DIR;
      } else {
        exit_myself(18,"Can't opendir: $Cgroup_directory_collection_links/cpuset/$Cpuset->{cpuset_path}");
      }
      if (opendir(DIR, $Cgroup_directory_collection_links.'/cpuset/'.$Cpuset->{cpuset_path}.'/')) {
        @other_cpusets = grep { /^.*_\d+$/ } readdir(DIR);
        closedir DIR;
      } else {
        exit_myself(18,"Can't opendir: $Cgroup_directory_collection_links/cpuset/$Cpuset->{cpuset_path}");
      }
    }

    if ($#cpusets < 0) {
      # No other jobs on this node at this time

      # Reboot if uptime > max_uptime
      if ( $#other_cpusets < 0 and $uptime > $max_uptime and $max_uptime > 0 and not -e "/etc/oar/dont_reboot") {
        print_log(3,"Max uptime reached, rebooting node.");
        system("/usr/lib/oar/oardodo/oardodo /sbin/reboot");
        exit(0);
      }

      my $useruid=getpwnam($Cpuset->{user});
      if (not defined($useruid)){
        print_log(3,"Cannot get information from user '$Cpuset->{user}' job #'$Cpuset->{job_id}'");
      }
      my $ipcrm_args="";
      if (open(IPCMSG,"< /proc/sysvipc/msg")) {
        <IPCMSG>;
        while (<IPCMSG>) {
          if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}/) {
            $ipcrm_args .= " -q $1";
            print_log(3,"Found IPC MSG for user $useruid: $1.");
          }
        }
        close (IPCMSG);
      } else {
        print_log(3,"Cannot open /proc/sysvipc/msg: $!.");
      }
      if (open(IPCSHM,"< /proc/sysvipc/shm")) {
        <IPCSHM>;
        while (<IPCSHM>) {
          if (/^\s*\d+\s+(\d+)(?:\s+\d+){5}\s+$useruid(?:\s+\d+){6}/) {
            $ipcrm_args .= " -m $1";
            print_log(3,"Found IPC SHM for user $useruid: $1.");
          }
        }
        close (IPCSHM);
      } else {
        print_log(3,"Cannot open /proc/sysvipc/shm: $!.");
      }
      if (open(IPCSEM,"< /proc/sysvipc/sem")) {
        <IPCSEM>;
        while (<IPCSEM>) {
          if (/^\s*[\d\-]+\s+(\d+)(?:\s+\d+){2}\s+$useruid(?:\s+\d+){5}/) {
            $ipcrm_args .= " -s $1";
            print_log(3,"Found IPC SEM for user $useruid: $1.");
          }
        }
        close (IPCSEM);
      } else {
        print_log(3,"Cannot open /proc/sysvipc/sem: $!.");
      }
      if ($ipcrm_args) {
        print_log (3,"Purging SysV IPC: ipcrm $ipcrm_args.");
        system_with_log("OARDO_BECOME_USER=$Cpuset->{user} oardodo ipcrm $ipcrm_args");
      }
      print_log (3,"Purging @Tmp_dir_to_clear.");
      system_with_log('for d in '."@Tmp_dir_to_clear".'; do
                         oardodo find $d -user '.$Cpuset->{user}.' -delete
                         [ -x '.$Fstrim_cmd.' ] && oardodo '.$Fstrim_cmd.' $d > /dev/null 2>&1
                       done
                      ');
    } else {
      print_log(3,"Not purging SysV IPC and /tmp as $Cpuset->{user} still has a job running on this host.");
    }
    flock(LOCK,LOCK_UN) or die "flock failed: $!\n";
    close(LOCK);
  }
  print_log(3,"Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env");
  unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{name}.env");
  print_log(3,"Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
  unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}");
  print_log(3,"Remove file $Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
  unlink("$Cpuset->{oar_tmp_directory}/$Cpuset->{job_id}_resources");
}else{
  exit_myself(3,"Bad command line argument $ARGV[0]");
}

exit(0);

# Print error message and exit
sub exit_myself($$){
  my $exit_code = shift;
  my $str = shift;

  warn("[job_resource_manager_systemd][$Cpuset->{job_id}][$ENV{TAKTUK_HOSTNAME}][ERROR] $str\n");
  exit($exit_code);
}

# Print log message depending on the LOG_LEVEL config value
sub print_log($$){
  my $l = shift;
  my $str = shift;

  if ($l <= $Log_level){
    print("[job_resource_manager_systemd][$Cpuset->{job_id}][$ENV{TAKTUK_HOSTNAME}][DEBUG] $str\n");
  }
}
# Run a command after printing it in the logs if OAR log level ≥ 4
sub system_with_log($) {
  my $command = shift;
  if (4 <= $Log_level){
    # Remove extra leading spaces in the command for the log, but preserve indentation
    my $log = $command;
    my @leading_spaces_lenghts = map {length($_)} ($log =~ /^( +)/mg);
    my $leading_spaces_to_remove = (sort {$a<=>$b} @leading_spaces_lenghts)[0];
    if (defined($leading_spaces_to_remove)){
      $log =~ s/^ {$leading_spaces_to_remove}//mg;
    }
    print_log(4, "System command:\n".$log);
  }
  return system($command);
}

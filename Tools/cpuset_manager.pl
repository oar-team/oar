# This script is executed as oar

# ARGV[0] can have two different values:
#     - "init"  : then this script must create the right cpuset and assign
#                 corresponding cpus
#     - "clean" : then this script must kill all processes in the cpuset and
#                 clean the cpuset structure

# TAKTUK_HOSTNAME envirionment variable must be defined and must be a name
# that we will be able to find in the transfered hashtable.

my $Cpuset;
my $Data_structure_transfer_timeout = 30;

eval {
    $SIG{ALRM} = sub { die "alarm\n" };
    alarm($Data_structure_transfer_timeout);
    $Cpuset = eval( <STDIN> );
    alarm(0);
};
if( $@ ){
    print("[cpuset_manager] Timeout of hashtable SSH transfer\n");
    exit(1);
}
# Get the data structure only for this node
my $Cpuset_name = $Cpuset->{name};
my @Cpuset_cpus = @{$Cpuset->{nodes}->{$ENV{TAKTUK_HOSTNAME}}};
if (!defined($Cpuset_name)){
    print("[cpuset_manager] Bad SSH hashtable transfered\n");
    exit(2);
}

# From now, "Cpuset" is of the form: 
# $Cpuset = {
#               name => "cpuset name",
#               nodes => hostname => [array with all cpus of this cpuset]
#           }
#
# $Cpuset_name is the name of the cpuset
# @Cpuset_cpus is the list of the cpuset DB field for this host

if ($ARGV[0] eq "init"){
    # Initialize cpuset for this node

    #print("[cpuset_manager] name = $Cpuset_name ; cpus = @Cpuset_cpus\n");
    if (system('sudo mount -t cpuset | grep " /dev/cpuset " > /dev/null 2>&1')){
        if (system('sudo mkdir -p /dev/cpuset && sudo mount -t cpuset none /dev/cpuset')){
            exit(4);
        }
    }
 
#'cat /dev/cpuset/mems > /dev/cpuset/'.$Cpuset_name.'/mems && '.

# Be careful with the physical_package_id. Is it corresponding to the memory banc?
    if (system( 'sudo mkdir -p /dev/cpuset/'.$Cpuset_name.' && '.
                'sudo chown -R oar /dev/cpuset/'.$Cpuset_name.' && '.
                '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_name.'/notify_on_release && '.
                '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_name.'/cpu_exclusive && '.
                'for c in '."@Cpuset_cpus".';do cat /sys/devices/system/cpu/cpu$c/topology/physical_package_id > /dev/cpuset/'.$Cpuset_name.'/mems; done && '.
                '/bin/echo '.join(",",@Cpuset_cpus).' | cat > /dev/cpuset/'.$Cpuset_name.'/cpus'
              )){
        exit(5);
    }
}elsif ($ARGV[0] eq "clean"){
    # Clean cpuset on this node

    system('PROCESSES=$(cat /dev/cpuset/'.$Cpuset_name.'/tasks)
            while [ "$PROCESSES" != "" ]
            do
                sudo kill -9 $PROCESSES
                PROCESSES=$(cat /dev/cpuset/'.$Cpuset_name.'/tasks)
            done'
          );

    if (system('sudo rmdir /dev/cpuset/'.$Cpuset_name)){
        # Uncomment this line if you want to use several network_address properties
        # which are the same physical computer (linux kernel)
        #exit(0);
        exit(6);
    }
}else{
    print("[cpuset_manager] Bad command line argument $ARGV[0].\n");
    exit(3);
}

exit(0);


# This script is executed as root

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
#               nodes => [array with all cpus of this cpuset]
#           }
#
# $Cpuset_name is the name of the cpuset
# @Cpuset_cpus is the list of cpus for this host

if ($ARGV[0] eq "init"){
    # Initialize cpuset for this node

    #print("[cpuset_manager] name = $Cpuset_name ; cpus = @Cpuset_cpus\n");
    if (system('mount -t cpuset | grep " /dev/cpuset " > /dev/null 2>&1')){
        if (system('mkdir -p /dev/cpuset && mount -t cpuset none /dev/cpuset')){
            exit(4);
        }
    }
 
    if (system( 'mkdir -p /dev/cpuset/'.$Cpuset_name.' && '.
                '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_name.'/notify_on_release && '.
                '/bin/echo 0 | cat > /dev/cpuset/'.$Cpuset_name.'/cpu_exclusive && '.
                'cat /dev/cpuset/mems > /dev/cpuset/'.$Cpuset_name.'/mems && '.
                '/bin/echo '.join(",",@Cpuset_cpus).' | cat > /dev/cpuset/'.$Cpuset_name.'/cpus && '.
                'chown oar /dev/cpuset/'.$Cpuset_name.'/tasks'
              )){
        exit(5);
    }
}elsif ($ARGV[0] eq "clean"){
    # Clean cpuset on this node

    system('PROCESSES=$(cat /dev/cpuset/'.$Cpuset_name.'/tasks)
            while [ "$PROCESSES" != "" ]
            do
                kill -9 $PROCESSES
                PROCESSES=$(cat /dev/cpuset/'.$Cpuset_name.'/tasks)
            done'
          );

    if (system('rmdir /dev/cpuset/'.$Cpuset_name)){
        exit(6);
    }
}else{
    print("[cpuset_manager] Bad command line argument $ARGV[0].\n");
    exit(3);
}

exit(0);


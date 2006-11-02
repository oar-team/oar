# This script is executed as oar

# ARGV[0] can have two different values:
#     - "suspend"  :    then this script must perform right commands to suspend
#                       all processes of the corresponding cpuset
#     - "resume"   :    then this script must resume alld processes previously
#                       suspended

my $Hash;
my $Data_structure_transfer_timeout = 30;

eval {
    $SIG{ALRM} = sub { die "alarm\n" };
    alarm($Data_structure_transfer_timeout);
    $Hash = eval( <STDIN> );
    alarm(0);
};
if( $@ ){
    print("[suspend_resume_manager] Timeout of hashtable SSH transfer\n");
    exit(1);
}
# Get the cpuset name
my $Cpuset_name = $Hash->{name};
if (!defined($Cpuset_name)){
    print("[suspend_resume_manager] Bad SSH hashtable transfered\n");
    exit(2);
}

# From now, "Hash" is of the form: 
# $Hash = {
#           name => "cpuset name",
#         }
#
# $Cpuset_name is the name of the cpuset

if ($ARGV[0] eq "suspend"){
    # Suspend all processes of the cpuset

    system('PROCESSES=$(cat /dev/cpuset/'.$Cpuset_name.'/tasks)
            sudo kill -SIGSTOP $PROCESSES'
          );
}elsif ($ARGV[0] eq "resume"){
    # Resume all processes of the cpuset

    system('PROCESSES=$(cat /dev/cpuset/'.$Cpuset_name.'/tasks)
            sudo kill -SIGCONT $PROCESSES'
          );
}else{
    print("[suspend_resume_manager] Bad command line argument $ARGV[0].\n");
    exit(3);
}

exit(0);


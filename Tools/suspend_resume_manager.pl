# This script is executed as oar
# $Id$
# ARGV[0] can have two different values:
#     - "suspend"  :    then this script must perform right commands to suspend
#                       all processes of the corresponding cpuset
#     - "resume"   :    then this script must resume alld processes previously
#                       suspended

my $Old_umask = sprintf("%lo",umask());
umask(oct("022"));

my $Hash;

my $tmp = "";
while (<STDIN>){
    $tmp .= $_;
}
$Hash = eval($tmp);

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

    system('PROCESSES=$(cat /dev/cpuset/oar/'.$Cpuset_name.'/tasks)
            oardo kill -SIGSTOP $PROCESSES'
          );
}elsif ($ARGV[0] eq "resume"){
    # Resume all processes of the cpuset

    system('PROCESSES=$(cat /dev/cpuset/oar/'.$Cpuset_name.'/tasks)
            oardo kill -SIGCONT $PROCESSES'
          );
}else{
    print("[suspend_resume_manager] Bad command line argument $ARGV[0].\n");
    exit(3);
}

exit(0);


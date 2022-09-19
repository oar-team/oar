# This script is executed as oar
# ARGV[0] can have two different values:
#     - "suspend"  :    then this script must perform right commands to suspend
#                       all processes of the corresponding cpuset
#     - "resume"   :    then this script must resume alld processes previously
#                       suspended

my $Old_umask = sprintf("%lo", umask());
umask(oct("022"));

my $Hash;

my $tmp = "";
while (<STDIN>) {
    $tmp .= $_;
}
$Hash = eval($tmp);

# Get the cpuset name
my $Cpuset_name = $Hash->{name};
if (!defined($Cpuset_name)) {
    print("[suspend_resume_manager] Bad SSH hashtable transfered\n");
    exit(2);
}

# From now, "Hash" is of the form:
# $Hash = {
#           name => "cpuset name",
#           job_id => "job id",
#           oarexec_pid_file => "file which contains the oarexec pid"
#         }
#
# $Cpuset_name is the name of the cpuset

my $oarexec_pid_file = $Hash->{oarexec_pid_file};

if ($ARGV[0] eq "suspend") {

    # Suspend all processes of the cpuset
    if (-r "/dev/oar_cgroups_links/freezer/oar/$Cpuset_name/freezer.state") {

        # We use the FREEZER cgroups feature if it is available
        system(
            'echo FROZEN > /dev/oar_cgroups_links/freezer/oar/' . $Cpuset_name . '/freezer.state');
    } else {
        system(
            '#set -x;
                PROC=0;
                test -e ' . $oarexec_pid_file . ' && PROC=$(cat ' . $oarexec_pid_file . ');
                for p in $(cat /dev/cpuset/oar/' . $Cpuset_name . '/tasks)
                do
                if [ $PROC != $p ]
                then
                    oardodo kill -SIGSTOP $p;
                fi
                done
              ');
    }
} elsif ($ARGV[0] eq "resume") {

    # Resume all processes of the cpuset
    if (-r "/dev/oar_cgroups_links/freezer/oar/$Cpuset_name/freezer.state") {

        # We use the FREEZER cgroups feature if it is available
        system(
            'echo THAWED > /dev/oar_cgroups_links/freezer/oar/' . $Cpuset_name . '/freezer.state');
    } else {
        system(
            'PROCESSES=$(cat /dev/cpuset/oar/' . $Cpuset_name . '/tasks)
                oardodo kill -SIGCONT $PROCESSES
               ');
    }
} else {
    print("[suspend_resume_manager] Bad command line argument $ARGV[0].\n");
    exit(3);
}

exit(0);


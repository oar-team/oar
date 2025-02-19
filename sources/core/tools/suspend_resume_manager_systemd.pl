# This script is executed as oar
# ARGV[0] can have two different values:
#     - "suspend"  :    then this script must perform right commands to suspend
#                       all processes of the corresponding cpuset
#     - "resume"   :    then this script must resume alld processes previously
#                       suspended

my $Hash;
my $tmp = "";
while (<STDIN>) {
    $tmp .= $_;
}
$Hash = eval($tmp);

# From now, "Hash" is of the form:
# $Hash = {
#           name => "cpuset name",
#           job_id => "job id",
#           job_user => "job user",
#           oarexec_pid_file => "file which contains the oarexec pid"
#         }
#
if (not defined($Hash->{job_user}) or not defined($Hash->{job_id})) {
    print("[suspend_resume_manager] Bad SSH hashtable transfered\n");
    exit(2);
}
my $Cpuset_user_id = getpwnam($Hash->{job_user});
my $Systemd_job_slice = "oar-u$Cpuset_user_id-j$Hash->{job_id}.slice";

if ($ARGV[0] eq "suspend") {
    # Suspend all processes of the cpuset
    system('busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
        . "org.freedesktop.systemd1.Manager FreezeUnit s $Systemd_job_slice");
} elsif ($ARGV[0] eq "resume") {
    system('busctl call -q org.freedesktop.systemd1 /org/freedesktop/systemd1 '
        . "org.freedesktop.systemd1.Manager ThawUnit s $Systemd_job_slice");
} else {
    print("[suspend_resume_manager] Bad command line argument $ARGV[0].\n");
    exit(3);
}

exit(0);

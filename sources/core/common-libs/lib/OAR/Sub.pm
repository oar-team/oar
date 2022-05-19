package OAR::Sub;

use strict;
use warnings;

use OAR::Version;
use OAR::Tools;
use OAR::IO;
use IO::Socket::INET;

my $base;

sub open_db_connection() {
    $base = OAR::IO::connect();
}

sub open_ro_db_connection() {
    $base = OAR::IO::connect_ro();
}

sub close_db_connection() {
    OAR::IO::disconnect($base) if (defined($base));
    $base = undef;
}

sub lock_tables($) {
    my $tables_to_lock = shift;
    OAR::IO::lock_table($base, $tables_to_lock);
}

sub unlock_tables() {
    OAR::IO::unlock_table($base);
}

sub encode_result($$) {
    my $result   = shift or die("[OAR::Nodes] encode_result: no result to encode");
    my $encoding = shift or die("[OAR::Nodes] encode_result: no format to encode to");
    if ($encoding eq "XML") {
        eval "use XML::Dumper qw(pl2xml);1" or die("XML module not available");
        my $dump = new XML::Dumper;
        $dump->dtd;
        my $return = $dump->pl2xml($result) or die("XML conversion failed");
        return $return;
    } elsif ($encoding eq "YAML") {
        eval "use YAML::Syck;1" or eval "use YAML;1" or die("No Perl YAML module is available");
        my $return = Dump($result) or die("YAML conversion failed");
        return $return;
    } elsif ($encoding eq "JSON") {
        eval "use JSON;1" or die("No Perl JSON module is available");
        my $return = JSON->new->pretty(1)->encode($result) or die("JSON conversion failed");
        return $return;
    }
}

sub get_oar_version() {
    return OAR::Version::get_version();
}

sub signal_almighty($$$) {
    my $almighty_hostname = shift;
    my $almighty_port     = shift;
    my $message           = shift;
    OAR::Tools::notify_tcp_socket($almighty_hostname, $almighty_port, $message);
}

sub get_job($) {
    my $job_id = shift;
    return OAR::IO::get_job($base, $job_id);
}

sub frag_job($) {
    my $job = shift;
    return OAR::IO::frag_job($base, $job);
}

#Used when we must have a response from the server
sub init_tcp_server() {
    my $server = IO::Socket::INET->new(
        Proto  => 'tcp',
        Reuse  => 1,
        Listen => 1
      ) or
      die("/!\\ Cannot initialize a TCP socket server.\n");
    my $server_port = $server->sockport();
    return ($server, $server_port);
}

#Read user script and extract OAR submition options
sub scan_script($$) {
    my $file                   = shift;
    my $Initial_request_string = shift;
    my %result;
    my $error = 0;
    ($file) = split(" ", $file);
    my $lusr = $ENV{OARDO_USER};
    $ENV{OARDO_BECOME_USER} = $lusr;
    if (open(FILE, "oardodo cat $file |")) {
        if (<FILE> =~ /^#/) {
            while (<FILE>) {
                if (/^#OAR\s+/) {
                    my $line = $_;
                    $line =~ s/\s+$//;
                    if ($line =~ m/^#OAR\s+(-l|--resource)\s*(.+)\s*$/m) {
                        push(@{ $result{resources} }, $2);
                    } elsif ($line =~ m/^#OAR\s+(-q|--queue)\s*(.+)\s*$/m) {
                        $result{queue} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-p|--property)\s*(.+)\s*$/m) {
                        $result{property} = $2;
                    } elsif ($line =~ m/^#OAR\s+(--checkpoint)\s*(\d+)\s*$/m) {
                        $result{checkpoint} = $2;
                    } elsif ($line =~ m/^#OAR\s+(--notify)\s*(.+)\s*$/m) {
                        $result{notify} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-t|--type)\s*(.+)\s*$/m) {
                        push(@{ $result{types} }, $2);
                    } elsif ($line =~ m/^#OAR\s+(-d|--directory)\s*(.+)\s*$/m) {
                        $result{directory} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-n|--name)\s*(.+)\s*$/m) {
                        $result{name} = $2;
                    } elsif ($line =~ m/^#OAR\s+(--project)\s*(.+)\s*$/m) {
                        $result{project} = $2;
                    } elsif ($line =~ m/^#OAR\s+(--hold)\s*$/m) {
                        $result{hold} = 1;
                    } elsif ($line =~ m/^#OAR\s+(-a|--anterior)\s*(\d+)\s*$/m) {
                        push(@{ $result{anterior} }, $2);
                    } elsif ($line =~ m/^#OAR\s+(--signal)\s*(\d+)\s*$/m) {
                        $result{signal} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-O|--stdout)\s*(.+)\s*$/m) {
                        $result{stdout} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-E|--stderr)\s*(.+)\s*$/m) {
                        $result{stderr} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-k|--use-job-key)\s*$/m) {
                        $result{usejobkey} = 1;
                    } elsif ($line =~ m/^#OAR\s+(--import-job-key-inline-priv)\s*(.+)\s*$/m) {
                        $result{importjobkeyinlinepriv} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-i|--import-job-key-from-file)\s*(.+)\s*$/m) {
                        $result{importjobkeyfromfile} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-e|--export-job-key-to-file)\s*(.+)\s*$/m) {
                        $result{exportjobkeytofile} = $2;
                    } elsif ($line =~ m/^#OAR\s+(-s|--stagein)\s*(.+)\s*$/m) {
                        $result{stagein} = $2;
                    } elsif ($line =~ m/^#OAR\s+(--stagein-md5sum)\s*(.+)\s*$/m) {
                        $result{stageinmd5sum} = $2;
                    } elsif ($line =~ m/^#OAR\s+(--array)\s*(\d+)\s*$/m) {
                        $result{array} = $2;
                    } elsif ($line =~ m/^#OAR\s+(--array-param-file)\s*(.+)\s*$/m) {
                        $result{arrayparamfile} = $2;
                    } else {
                        warn("/!\\ Not able to scan file line: $line.");
                        $error++;
                    }
                    chomp($line);
                    $Initial_request_string .= "; $line";
                }
            }
        }
        if (!close(FILE)) {
            warn("[ERROR] Cannot open the file $file.\n");
            close_db_connection();
            exit(12);
        }
    } else {
        warn("[ERROR] Cannot execute: oardodo cat $file.\n");
        close_db_connection();
        exit(12);
    }
    if ($error > 0) {
        warn("[ERROR] $error error(s) encountered while parsing the file $file.\n");
        close_db_connection();
        exit(12);
    }
    $result{initial_request} = $Initial_request_string;
    return (\%result);
}

sub read_array_param_file($) {
    my $array_param_file = shift;
    my @array_params;
    if (open(PARAMETER_FILE, "oardodo cat $array_param_file |")) {
        while (<PARAMETER_FILE>) {
            s/#.*//;            # ignore comments by erasing them
            next if /^\s*$/;    # skip blank lines
            chomp;              # remove trailing newline characters
            push(@array_params, $_);
        }
        if (!close(PARAMETER_FILE)) {
            warn("[ERROR] Cannot open the parameter file $array_param_file.\n");
            close_db_connection();
            exit(12);
        }
    } else {
        warn("[ERROR] Cannot execute: oardodo cat $array_param_file.\n");
        close_db_connection();
        exit(12);
    }
    return \@array_params;
}

sub get_job_current_hostnames($) {
    my $job_id = shift;
    my @return = OAR::IO::get_job_current_hostnames($base, $job_id);
    return \@return;
}

sub get_current_job_types($) {
    my $job_id = shift;
    return OAR::IO::get_job_types_hash($base, $job_id);
}

sub get_job_cpuset_name($) {
    my $job_id = shift;
    return OAR::IO::get_job_cpuset_name($base, $job_id);
}

sub get_current_moldable_job($) {
    my $moldable_job_id = shift;
    return OAR::IO::get_current_moldable_job($base, $moldable_job_id);
}

sub get_default_oarexec_directory() {
    return OAR::Tools::get_default_oarexec_directory();
}

sub set_default_oarexec_directory($) {
    my $dir = shift;
    OAR::Tools::set_default_oarexec_directory($dir);
}

sub get_oarsub_connections_file_name($) {
    my $job_id = shift;
    return OAR::Tools::get_oarsub_connections_file_name($job_id);
}

sub get_default_openssh_cmd() {
    return OAR::Tools::get_default_openssh_cmd();
}

sub set_ssh_timeout($) {
    my $timeout = shift;
    OAR::Tools::set_ssh_timeout($timeout);
}

sub get_oarexecuser_script_for_oarsub($) {
    my $params              = shift;
    my $node_file           = $params->{node_file};
    my $job_id              = $params->{job_id};
    my $array_id            = $params->{array_id};
    my $array_index         = $params->{array_index};
    my $user                = $params->{user};
    my $shell               = $params->{shell};
    my $launching_directory = $params->{launching_directory};
    my $resource_file       = $params->{resource_file};
    my $job_name            = $params->{job_name};
    my $job_project         = $params->{job_project};
    my $job_walltime        = $params->{job_walltime};
    my $job_walltime_sec    = $params->{job_walltime_sec};
    my $job_env             = $params->{job_env};
    return OAR::Tools::get_oarexecuser_script_for_oarsub(
        $node_file, $job_id,      $array_id,            $array_index,
        $user,      $shell,       $launching_directory, $resource_file,
        $job_name,  $job_project, $job_walltime,        $job_walltime_sec,
        $job_env);
}

sub signal_oarexec($) {
    my $params  = shift;
    my $host    = $params->{host};
    my $job_id  = $params->{job_id};
    my $signal  = $params->{signal};
    my $wait    = $params->{time_to_wait};
    my $base    = undef;
    my $ssh_cmd = $params->{ssh_cmd};
    return OAR::Tools::signal_oarexec($host, $job_id, $signal, $wait, $base, $ssh_cmd, '');
}

sub duration_to_sql($) {
    my $duration = shift;
    return OAR::IO::duration_to_sql($duration);
}

sub sql_to_duration($) {
    my $date = shift;
    return OAR::IO::sql_to_duration($date);
}

sub sql_to_local($) {
    my $date = shift;
    return OAR::IO::sql_to_local($date);
}

sub ymdhms_to_sql($$$$$$) {
    my ($year, $mon, $mday, $hour, $min, $sec) = @_;
    return OAR::IO::ymdhms_to_sql($year, $mon, $mday, $hour, $min, $sec);
}

sub resubmit_job($) {
    my $job_id = shift;
    return OAR::IO::resubmit_job($base, $job_id);
}

sub get_lock($$) {
    my $mutex   = shift;
    my $timeout = shift;
    return OAR::IO::get_lock($base, $mutex, $timeout);
}

sub release_lock($) {
    my $mutex = shift;
    return OAR::IO::release_lock($base, $mutex);
}

sub get_stagein_id($) {
    my $md5sum = shift;
    return OAR::IO::get_stagein_id($base, $md5sum);
}

sub set_stagein($) {
    my $params      = shift;
    my $md5sum      = $params->{md5sum};
    my $location    = $params->{location};
    my $method      = $params->{method};
    my $compression = $params->{compression};
    my $size        = $params->{size};
    return OAR::IO::set_stagein($base, $md5sum, $location, $method, $compression, $size);
}

sub get_job_array_id($) {
    my $job_id = shift;
    return OAR::IO::get_job_array_id($base, $job_id);
}

sub add_micheline_job {
    my ($jobType,                $ref_resource_list,   $command,
        $infoType,               $queue_name,          $jobproperties,
        $startTimeReservation,   $idFile,              $checkpoint,
        $checkpoint_signal,      $notify,              $job_name,
        $job_env,                $type_list,           $launching_directory,
        $anterior_ref,           $stdout,              $stderr,
        $job_hold,               $project,             $use_job_key,
        $import_job_key_inline,  $import_job_key_file, $export_job_key_file,
        $initial_request_string, $array_job_nb,        $array_params_ref,
        $verbose_level
    ) = @_;
    my $base_ro = OAR::IO::connect_ro();

    # Hide the ssh inline private key (if used) in the initial_request
    if ($import_job_key_inline ne "") {
        $initial_request_string =~ s/\Q$import_job_key_inline/[HIDDEN INLINE JOB KEY]/;
    }

    my $r = OAR::IO::add_micheline_job(
        $base,                $base_ro,             $jobType,
        $ref_resource_list,   $command,             $infoType,
        $queue_name,          $jobproperties,       $startTimeReservation,
        $idFile,              $checkpoint,          $checkpoint_signal,
        $notify,              $job_name,            $job_env,
        $type_list,           $launching_directory, $anterior_ref,
        $stdout,              $stderr,              $job_hold,
        $project,             $use_job_key,         $import_job_key_inline,
        $import_job_key_file, $export_job_key_file, $initial_request_string,
        $array_job_nb,        $array_params_ref,    $verbose_level);
    OAR::IO::disconnect($base_ro);
    return ($r);
}

sub delete_jobs($$$) {
    my $job_ids     = shift;
    my $remote_host = shift;
    my $remote_port = shift;
    open_db_connection();
    lock_tables([ "frag_jobs", "event_logs", "jobs" ]);
    foreach my $Job_id (@{$job_ids}) {
        warn("Deleting the job $Job_id...\n");
        my $err = frag_job($Job_id);
    }
    unlock_tables();
    close_db_connection();
    warn("Job(s) deleted.\n");

    #Signal Almigthy
    signal_almighty($remote_host, $remote_port, "Qdel");
}

sub get_running_jobs_for_user($) {
    my $user = shift;

    return (OAR::IO::get_jobs_in_state_for_user($base, "Running", $user));
}

1;


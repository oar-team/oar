package OAR::Schedulers::Quotas;
require Exporter;
use POSIX qw(strftime);
use Storable qw(dclone);
use OAR::Schedulers::Gantt;
use warnings;
use strict;

# Prototypes
# quota data management
sub new($);
sub read_conf_file($);
sub update_accounting_counters($$$$$$$$);
sub check_quotas($$$$$$$$$$$);
sub pretty_print($);
sub update_accounting_slot_data($$$$$$$);

###############################################################################

my $Security_time_overhead;

# Creates an accounting data structure for quotas
sub new($){
    $Security_time_overhead = shift;

    my $accounting_counters_init;
    # $accounting_counters_init->{'queue'}->{'project'}->{'type'}->{'user'} = [nb_used_resources, nb_running_jobs, resourcetime]
    $accounting_counters_init->{'*'}->{'*'}->{'*'}->{'*'} = [0,0,0];

    return( [                       # Accounting data storage for quotas: an array of array
                [                   # This is a chronological stack with:
                    0,              # - t_start: counters are valid from this date to the next array entry
                    $accounting_counters_init # - counters: hash ref of the accounting data    
                ],
                [
                    OAR::Schedulers::Gantt::get_infinity_value(),      # next array entry
                    undef
                ]
            ]);
}

# Read configuration file
sub read_conf_file($){
    my ($quota_file) = @_;

    my $msg;
    my $Gantt_quotas;
    # By default, no quota
    $Gantt_quotas->{'*'}->{'*'}->{'*'}->{'*'} = [-1,-1,-1];
    if (open(QUOTAFILE, "< $quota_file")){
        my $oldslurpmode = $/;
        undef $/;
        my $quota_file_content = <QUOTAFILE>;
        $/ = $oldslurpmode;
        close(QUOTAFILE);
        eval($quota_file_content);
        if ($@) {
            $msg = "Syntax error in file $quota_file: $@";
        }
    }else{
        $msg = "Cannot open file $quota_file: $!";
    }
    # Check if the values are just an integer (nb resources) or an array ref
    foreach my $q (keys(%{$Gantt_quotas})){
        foreach my $p (keys(%{$Gantt_quotas->{$q}})){
            foreach my $t (keys(%{$Gantt_quotas->{$q}->{$p}})){
                foreach my $u (keys(%{$Gantt_quotas->{$q}->{$p}->{$t}})){
                    if (! ref($Gantt_quotas->{$q}->{$p}->{$t}->{$u})){
                        $Gantt_quotas->{$q}->{$p}->{$t}->{$u} = [$Gantt_quotas->{$q}->{$p}->{$t}->{$u}, -1, -1];
                    }elsif ($#{$Gantt_quotas->{$q}->{$p}->{$t}->{$u}} < 2){
                        $Gantt_quotas->{$q}->{$p}->{$t}->{$u}->[2] = -1;
                    }
                }
            }
        }
    }

    return($Gantt_quotas, $msg);
}

# Return a string with the quota accounting data
sub pretty_print($){
    my ($accounting) = @_;
   
    my $str = "Accounting data for quotas:\n";
    my $index = 0;
    while ($index < $#{$accounting}){
        my $step_ref = $accounting->[$index];
        my $next_step_time = $accounting->[$index+1]->[0];
        $str .= "  $index From $step_ref->[0](".strftime("%F %T",localtime($step_ref->[0])).") To $next_step_time(".strftime("%F %T",localtime($next_step_time))."):\n";
        foreach my $i (sort(keys(%{$step_ref->[1]}))){
            foreach my $j (sort(keys(%{$step_ref->[1]->{$i}}))){
                foreach my $k (sort(keys(%{$step_ref->[1]->{$i}->{$j}}))){
                    foreach my $l (sort(keys(%{$step_ref->[1]->{$i}->{$j}->{$k}}))){
                        $str .= sprintf("    %16.16s > %16.16s > %10.10s > %10.10s = %i resources, %i jobs, %f resourcesXhours\n", $i, $j, $k, $l, $step_ref->[1]->{$i}->{$j}->{$k}->{$l}->[0], $step_ref->[1]->{$i}->{$j}->{$k}->{$l}->[1], $step_ref->[1]->{$i}->{$j}->{$k}->{$l}->[2]);
                    }
                }
            }
        }
        $index++;
    }
    return($str);
}

# Update accounting data
sub update_accounting_counters($$$$$$$$){
    my ( $accounting,
         $nb_resources,
         $date_start,
         $duration,
         $job_queue,
         $job_project,
         $job_types_arrayref,
         $job_user) = @_;

    my $array_id_to_insert1 = -1;
    my $array_id_to_insert2 = -1;
    my $date_stop = $date_start + $duration + 1;
    for (my $stackid = 0; $stackid < $#{$accounting}; $stackid++){
        # Update existing slots with the new job
        if (($accounting->[$stackid]->[0] >= $date_start) and ($accounting->[$stackid+1]->[0] <= $date_stop)){
            my $resourcesXhours = $nb_resources * (($date_stop - 1 - $accounting->[$stackid]->[0] - $Security_time_overhead) / 3600);
            update_accounting_slot_data($accounting->[$stackid]->[1], $job_queue, $job_project, $job_types_arrayref, $job_user, $nb_resources, $resourcesXhours);
        }
        # Get the index of the first slot to add
        if (($accounting->[$stackid]->[0] < $date_start) and ($accounting->[$stackid+1]->[0] > $date_start)){
            $array_id_to_insert1 = $stackid;
        }
        # Get the index of the last slot to add
        if (($accounting->[$stackid]->[0] < $date_stop) and ($accounting->[$stackid+1]->[0] > $date_stop)){
            $array_id_to_insert2 = $stackid;
            last();
        }
    }
    # Add new slot (end of job)
    if ($array_id_to_insert2 >= 0){
        splice(@{$accounting}, $array_id_to_insert2 + 1, 0, [ $date_stop , dclone($accounting->[$array_id_to_insert2]->[1]) ]);
        if ($accounting->[$array_id_to_insert2]->[0] >= $date_start){
            my $resourcesXhours = $nb_resources * (($date_stop - 1 - $accounting->[$array_id_to_insert2]->[0] - $Security_time_overhead) / 3600);
            update_accounting_slot_data($accounting->[$array_id_to_insert2]->[1], $job_queue, $job_project, $job_types_arrayref, $job_user, $nb_resources, $resourcesXhours);
        }
    }
    # Add new slot (start of job)
    if ($array_id_to_insert1 >= 0){
        splice(@{$accounting}, $array_id_to_insert1 + 1, 0, [ $date_start , dclone($accounting->[$array_id_to_insert1]->[1]) ]);
        my $resourcesXhours = $nb_resources * (($date_stop - 1 - $accounting->[$array_id_to_insert1+1]->[0] - $Security_time_overhead) / 3600);
        update_accounting_slot_data($accounting->[$array_id_to_insert1+1]->[1], $job_queue, $job_project, $job_types_arrayref, $job_user, $nb_resources, $resourcesXhours);
    }
}

# Update the hash of a slot for accounting data
# Internal function
sub update_accounting_slot_data($$$$$$$){
    my ( $counter_hashref,
         $queue,
         $project,
         $types_arrayref,
         $user,
         $nbresources,
         $resourcesXhours) = @_;

    $resourcesXhours = 0 if ($resourcesXhours < 0);
    foreach my $t (@{$types_arrayref},'*'){
        # Update the number of used resources
        $counter_hashref->{'*'}->{'*'}->{$t}->{'*'}->[0] += $nbresources;
        $counter_hashref->{'*'}->{'*'}->{$t}->{$user}->[0] += $nbresources;
        $counter_hashref->{'*'}->{$project}->{$t}->{'*'}->[0] += $nbresources;
        $counter_hashref->{$queue}->{'*'}->{$t}->{'*'}->[0] += $nbresources;
        $counter_hashref->{$queue}->{$project}->{$t}->{$user}->[0] += $nbresources;
        $counter_hashref->{$queue}->{$project}->{$t}->{'*'}->[0] += $nbresources;
        $counter_hashref->{$queue}->{'*'}->{$t}->{$user}->[0] += $nbresources;
        $counter_hashref->{'*'}->{$project}->{$t}->{$user}->[0] += $nbresources;
        # Update the number of running jobs
        $counter_hashref->{'*'}->{'*'}->{$t}->{'*'}->[1] += 1;
        $counter_hashref->{'*'}->{'*'}->{$t}->{$user}->[1] += 1;
        $counter_hashref->{'*'}->{$project}->{$t}->{'*'}->[1] += 1;
        $counter_hashref->{$queue}->{'*'}->{$t}->{'*'}->[1] += 1;
        $counter_hashref->{$queue}->{$project}->{$t}->{$user}->[1] += 1;
        $counter_hashref->{$queue}->{$project}->{$t}->{'*'}->[1] += 1;
        $counter_hashref->{$queue}->{'*'}->{$t}->{$user}->[1] += 1;
        $counter_hashref->{'*'}->{$project}->{$t}->{$user}->[1] += 1;
        # Update the resource X hours occupation (=~cputime)
        $counter_hashref->{'*'}->{'*'}->{$t}->{'*'}->[2] += $resourcesXhours;
        $counter_hashref->{'*'}->{'*'}->{$t}->{$user}->[2] += $resourcesXhours;
        $counter_hashref->{'*'}->{$project}->{$t}->{'*'}->[2] += $resourcesXhours;
        $counter_hashref->{$queue}->{'*'}->{$t}->{'*'}->[2] += $resourcesXhours;
        $counter_hashref->{$queue}->{$project}->{$t}->{$user}->[2] += $resourcesXhours;
        $counter_hashref->{$queue}->{$project}->{$t}->{'*'}->[2] += $resourcesXhours;
        $counter_hashref->{$queue}->{'*'}->{$t}->{$user}->[2] += $resourcesXhours;
        $counter_hashref->{'*'}->{$project}->{$t}->{$user}->[2] += $resourcesXhours;
    }
}

# Check if the job fit the quotas and when
# return the date when the quotas are satisfied
sub check_quotas($$$$$$$$$$$){
    my ( $accounting,
         $gantt_quotas,
         $current_time,
         $gantt_hole_date_stop,
         $gantt_next_hole_date_start,
         $duration,
         $job_queue,
         $job_project,
         $job_types_arrayref,
         $job_user,
         $nbresources_occupied_by_other_groups) = @_;

    my $resourcesXhours = $nbresources_occupied_by_other_groups * ($duration - $Security_time_overhead) / 3600; 
    my $comment = "quota_ok";
    my $qindex = 0;
#    print(pretty_print($accounting));
    
    # Check if quotas are satisfied in this hole and when
    while (($qindex < $#{$accounting})
            and ($accounting->[$qindex]->[0] < $gantt_hole_date_stop) # quota beginning slot inside the hole
            and ($current_time + $duration < $gantt_hole_date_stop) # quota slot not outside the hole
            and ($accounting->[$qindex]->[0] - $current_time < $duration) # continue until the quota slot is big enough
            and (($gantt_next_hole_date_start > 0) or ($gantt_next_hole_date_start > $current_time))
          ){
        if ($current_time < $accounting->[$qindex+1]->[0]){
            # Check the whole quotas
            my $q_counter; my $p_counter; my $u_counter;
            OUTER_LOOP:
            foreach my $q (keys(%{$gantt_quotas})){
                if (($q eq $job_queue) or ($q eq '*') or ($q eq '/')){
                    if (($q ne $job_queue) and (defined($gantt_quotas->{$job_queue}))){  # check if another rule is more specific
                        my $skip = 0;
                        foreach my $tmp_t (@{$job_types_arrayref},'*'){
                            if (defined($gantt_quotas->{$job_queue}->{$job_project}->{$tmp_t}->{$job_user})
                                or defined($gantt_quotas->{$job_queue}->{$job_project}->{$tmp_t}->{'*'})
                                or defined($gantt_quotas->{$job_queue}->{$job_project}->{$tmp_t}->{'/'})
                                or defined($gantt_quotas->{$job_queue}->{'*'}->{$tmp_t}->{$job_user})
                                or defined($gantt_quotas->{$job_queue}->{'/'}->{$tmp_t}->{$job_user})
                                or defined($gantt_quotas->{$job_queue}->{'*'}->{$tmp_t}->{'*'})
                                or defined($gantt_quotas->{$job_queue}->{'*'}->{$tmp_t}->{'/'})
                                or defined($gantt_quotas->{$job_queue}->{'/'}->{$tmp_t}->{'*'})
                                or defined($gantt_quotas->{$job_queue}->{'/'}->{$tmp_t}->{'/'})
                                ){
                                $skip = 1;
                                last;
                            }
                        }
                        next if ($skip == 1);
                    }
                    if ($q eq '/'){
                        $q_counter = $job_queue;
                    }else{
                        $q_counter = $q;
                    }
                    foreach my $p (keys(%{$gantt_quotas->{$q}})){
                        if (($p eq $job_project) or ($p eq '*') or ($p eq '/')){
                            if (($p ne $job_project) and (defined($gantt_quotas->{$q}->{$job_project}))){  # check if another rule is more specific
                                my $skip = 0;
                                foreach my $tmp_t (@{$job_types_arrayref},'*'){
                                    if (defined($gantt_quotas->{$q}->{$job_project}->{$tmp_t}->{$job_user})
                                        or defined($gantt_quotas->{$q}->{$job_project}->{$tmp_t}->{'*'})
                                        or defined($gantt_quotas->{$q}->{$job_project}->{$tmp_t}->{'/'})
                                        ){
                                        $skip = 1;
                                        last;
                                    }
                                }
                                next if ($skip == 1);
                            }
                            if ($p eq '/'){
                                $p_counter = $job_project;
                            }else{
                                $p_counter = $p;
                            }
                            foreach my $t (keys(%{$gantt_quotas->{$q}->{$p}})){
                                if ($t eq '*'){  # check if another rule is more specific
                                    my $skip = 0;
                                    foreach my $tmp_t (@{$job_types_arrayref}){
                                        if (defined($gantt_quotas->{$q}->{$p}->{$tmp_t}->{$job_user})
                                            or defined($gantt_quotas->{$q}->{$p}->{$tmp_t}->{'*'})
                                            or defined($gantt_quotas->{$q}->{$p}->{$tmp_t}->{'/'})
                                            ){
                                            $skip = 1;
                                            last;
                                        }
                                    }
                                    next if ($skip == 1);
                                }
                                foreach my $job_t (@{$job_types_arrayref},'*'){
                                    if ($t eq $job_t){
                                        foreach my $u (keys(%{$gantt_quotas->{$q}->{$p}->{$t}})){
                                            if (($u ne $job_user) and defined($gantt_quotas->{$q}->{$p}->{$t}->{$job_user})){  # check if another rule is more specific
                                                next;
                                            }
                                            if (($u eq $job_user) or ($u eq '*') or ($u eq '/')){
                                                if ($u eq '/'){
                                                    $u_counter = $job_user;
                                                }else{
                                                    $u_counter = $u;
                                                }
                                                if (($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[0] >= 0) or
                                                    ($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[1] >= 0) or
                                                    ($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[2] >= 0)
                                                   ){
                                                    # Get previous nb resources used by the previous group of the job
                                                    my $tmp_account = $nbresources_occupied_by_other_groups;
                                                    my $tmp_nbjobs_account = 1;
                                                    my $tmp_resourcesXhours_account = $resourcesXhours;
                                                    if (defined($accounting->[$qindex]->[1]->{$q_counter}->{$p_counter}->{$t}->{$u_counter})){
                                                        # Add existing accounting data from the other jobs
                                                        $tmp_account += $accounting->[$qindex]->[1]->{$q_counter}->{$p_counter}->{$t}->{$u_counter}->[0];
                                                        $tmp_nbjobs_account += $accounting->[$qindex]->[1]->{$q_counter}->{$p_counter}->{$t}->{$u_counter}->[1];
                                                        $tmp_resourcesXhours_account += $accounting->[$qindex]->[1]->{$q_counter}->{$p_counter}->{$t}->{$u_counter}->[2];
                                                        if ($current_time > $accounting->[$qindex]->[0]){
                                                            $tmp_resourcesXhours_account -= ($accounting->[$qindex]->[1]->{$q_counter}->{$p_counter}->{$t}->{$u_counter}->[0] * ($current_time - $accounting->[$qindex]->[0])) / 3600;
                                                        }
                                                    }
                                                    if ((($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[0] < $tmp_account) and ($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[0] >= 0)) or
                                                        (($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[1] < $tmp_nbjobs_account) and ($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[1] >= 0)) or
                                                        (($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[2] < $tmp_resourcesXhours_account) and ($gantt_quotas->{$q}->{$p}->{$t}->{$u}->[2] >= 0))
                                                       ){
                                                        $tmp_resourcesXhours_account = sprintf("%.2f", $tmp_resourcesXhours_account);
                                                        $comment = "quota_exceeded:Gantt_quotas->{$q}->{$p}->{$t}->{$u}=\[$tmp_account,$tmp_nbjobs_account,$tmp_resourcesXhours_account\]>\[$gantt_quotas->{$q}->{$p}->{$t}->{$u}->[0],$gantt_quotas->{$q}->{$p}->{$t}->{$u}->[1],$gantt_quotas->{$q}->{$p}->{$t}->{$u}->[2]\]";
                                                        $current_time = $accounting->[$qindex+1]->[0];
                                                        last OUTER_LOOP;
                                                    }else{
                                                        $comment = "quota_ok";
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        $qindex++;
    }
    return($current_time, $comment);
}

return 1;

# $Id$
package OAR::Schedulers::QuotaStorage;
require Exporter;
use POSIX qw(strftime);
use Storable qw(store_fd fd_retrieve dclone);
use OAR::Schedulers::GanttHoleStorage_with_quotas;
use warnings;
use strict;

# Prototypes
# quota data management
sub new();
sub read_conf_file($);
sub update_accounting_counters($$$$$$$$);
sub check_quotas($$$$$$$$$$$);
sub pretty_print($);
###############################################################################

# Creates an accounting data structure for quotas
sub new(){
    my $accounting_counters_init;
    # $accounting_counters_init->{'queue'}->{'project'}->{'type'}->{'user'} = nb_used_resources
    $accounting_counters_init->{'*'}->{'*'}->{'*'}->{'*'} = 0;

    return( [                       # Accounting data storage for quotas: an array of array
                [                   # This is a chronological stack with:
                    0,              # - t_start: counters are valid from this date to the next array entry
                    $accounting_counters_init # - counters: hash ref of the accounting data    
                ],
                [
                    OAR::Schedulers::GanttHoleStorage_with_quotas::get_infinity_value(),      # next array entry
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
    $Gantt_quotas->{'*'}->{'*'}->{'*'}->{'*'} = -1;
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
        $msg = "Cannot open  file $quota_file: $!";
    }

    return($Gantt_quotas, $msg);
}

# Print the quota accounting data
sub pretty_print($){
    my ($accounting) = @_;
   
    print("Accounting data for quotas:\n");
    my $index = 0;
    while ($index < $#{$accounting}){
        my $step_ref = $accounting->[$index];
        my $next_step_time = $accounting->[$index+1]->[0];
        print("  $index From $step_ref->[0](".strftime("%F %T",localtime($step_ref->[0])).") To $next_step_time(".strftime("%F %T",localtime($next_step_time))."):\n");
        foreach my $i (sort(keys($step_ref->[1]))){
            foreach my $j (sort(keys($step_ref->[1]->{$i}))){
                foreach my $k (sort(keys($step_ref->[1]->{$i}->{$j}))){
                    foreach my $l (sort(keys($step_ref->[1]->{$i}->{$j}->{$k}))){
                        printf("    %16.16s > %16.16s > %10.10s > %10.10s = %i\n", $i, $j, $k, $l, $step_ref->[1]->{$i}->{$j}->{$k}->{$l});
                    }
                }
            }
        }
        $index++;
    }
}

# Update accounting data for quotas
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
            update_accounting_slot_data($accounting->[$stackid]->[1], $job_queue, $job_project, $job_types_arrayref, $job_user, $nb_resources);
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
            update_accounting_slot_data($accounting->[$array_id_to_insert2]->[1], $job_queue, $job_project, $job_types_arrayref, $job_user, $nb_resources);
        }
    }
    # Add new slot (start of job)
    if ($array_id_to_insert1 >= 0){
        splice(@{$accounting}, $array_id_to_insert1 + 1, 0, [ $date_start , dclone($accounting->[$array_id_to_insert1]->[1]) ]);
        update_accounting_slot_data($accounting->[$array_id_to_insert1+1]->[1], $job_queue, $job_project, $job_types_arrayref, $job_user, $nb_resources);
    }
}

# Update the hash of a slot for accounting data
# Internal function
sub update_accounting_slot_data($$$$$$){
    my ( $counter_hashref,
         $queue,
         $project,
         $types_arrayref,
         $user,
         $nbresources) = @_;

    foreach my $t (@{$types_arrayref},'*'){
        $counter_hashref->{'*'}->{'*'}->{$t}->{'*'} += $nbresources;
        $counter_hashref->{'*'}->{'*'}->{$t}->{$user} += $nbresources;
        $counter_hashref->{'*'}->{$project}->{$t}->{'*'} += $nbresources;
        $counter_hashref->{$queue}->{'*'}->{$t}->{'*'} += $nbresources;
        $counter_hashref->{$queue}->{$project}->{$t}->{$user} += $nbresources;
        $counter_hashref->{$queue}->{$project}->{$t}->{'*'} += $nbresources;
        $counter_hashref->{$queue}->{'*'}->{$t}->{$user} += $nbresources;
        $counter_hashref->{'*'}->{$project}->{$t}->{$user} += $nbresources;
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
    
    #pretty_print($accounting);
    my $qindex = 0;
    print("QUOTA CHECK INIT\n");
    # Check if quotas are satisfied in this hole and when
    while (($qindex < $#{$accounting})
            and ($accounting->[$qindex]->[0] < $gantt_hole_date_stop) # quota beginning slot inside the hole
            and ($current_time + $duration < $gantt_hole_date_stop) # quota slot not outside the hole
            and ($accounting->[$qindex]->[0] - $current_time < $duration) # continue until the quota slot is big enough
            and (($gantt_next_hole_date_start > 0) or ($gantt_next_hole_date_start > $current_time))
          ){
        if ($current_time < $accounting->[$qindex+1]->[0]){
            # Check the whole quotas
            print("QUOTA CHECK: slot ($qindex) $accounting->[$qindex]->[0](".strftime("%F %T",localtime($accounting->[$qindex]->[0])).") --> $accounting->[$qindex+1]->[0](".strftime("%F %T",localtime($accounting->[$qindex+1]->[0])).")\n");
            my $q_counter; my $p_counter; my $u_counter;
            OUTER_LOOP:
            foreach my $q (keys($gantt_quotas)){
                if (($q eq $job_queue) or ($q eq '*') or ($q eq '/')){
                    if ($q eq '/'){
                        $q_counter = $job_queue;
                    }else{
                        $q_counter = $q;
                    }
                    foreach my $p (keys($gantt_quotas->{$q})){
                        if (($p eq $job_project) or ($p eq '*') or ($p eq '/')){
                            if ($p eq '/'){
                                $p_counter = $job_project;
                            }else{
                                $p_counter = $p;
                            }
                            foreach my $t (keys($gantt_quotas->{$q}->{$p})){
                                foreach my $job_t (@{$job_types_arrayref},'*'){
                                    if ($t eq $job_t){
                                        foreach my $u (keys($gantt_quotas->{$q}->{$p}->{$t})){
                                            if ($u eq '/'){
                                                $u_counter = $job_user;
                                            }else{
                                                $u_counter = $u;
                                            }
                                            if ($gantt_quotas->{$q}->{$p}->{$t}->{$u} >= 0){
                                                # Get previous nb resources used by the previous group of the job
                                                my $tmp_account = $nbresources_occupied_by_other_groups;
                                                if (defined($accounting->[$qindex]->[1]->{$q_counter}->{$p_counter}->{$t}->{$u_counter})){
                                                    # Add existing accounting data from the other jobs
                                                    $tmp_account += $accounting->[$qindex]->[1]->{$q_counter}->{$p_counter}->{$t}->{$u_counter};
                                                }
                                                if ($gantt_quotas->{$q}->{$p}->{$t}->{$u} < $tmp_account){
                                                    print("QUOTA EXCEEDED: Gantt_quotas->{$q}->{$p}->{$t}->{$u} $tmp_account > $gantt_quotas->{$q}->{$p}->{$t}->{$u}\n");
                                                    $current_time = $accounting->[$qindex+1]->[0];
                                                    last OUTER_LOOP;
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
    print("QUOTA CHECK returns: $current_time(".strftime("%F %T",localtime($current_time)).")\n");
    return($current_time);
}

return 1;

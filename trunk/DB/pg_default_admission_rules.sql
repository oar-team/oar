-- Default insertions
-- Specify the default value for queue parameter
INSERT INTO admission_rules (rule) VALUES ('if (not defined($queue_name)) {$queue_name="default";}');
-- Avoid users except oar to go in the admin queue
INSERT INTO admission_rules (rule) VALUES ('if (($queue_name eq "admin") && ($user ne "oar")) {die("[ADMISSION RULE] Only the user oar can submit jobs in the admin queue\\n");}');

-- Force besteffort jobs to go on nodes with the besteffort property
INSERT INTO admission_rules (rule) VALUES ('
if (grep(/^besteffort$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND besteffort = \\\'YES\\\'";
    }else{
        $jobproperties = "besteffort = \\\'YES\\\'";
    }
    print("[ADMISSION RULE] Added automatically besteffort resource constraint\\n");
}
');

-- Force besteffort jobs to go in the besteffort queue
INSERT INTO admission_rules (rule) VALUES ('
if (grep(/^besteffort$/, @{$type_list})){
    $queue_name = "besteffort";
    print("[ADMISSION RULE] Redirect automatically in the besteffort queue\\n");
}
');

-- Verify if besteffort jobs are not reservations
INSERT INTO admission_rules (rule) VALUES ('
if ((grep(/^besteffort$/, @{$type_list})) and ($reservationField ne "None")){
    die("[ADMISSION RULE] Error : a besteffort typed job cannot be a reservation.\\n");
}
');

-- Force deploy jobs to go on nodes with the deploy property
INSERT INTO admission_rules (rule) VALUES ('
if (grep(/^deploy$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND deploy = \\\'YES\\\'";
    }else{
        $jobproperties = "deploy = \\\'YES\\\'";
    }
}
');

-- Force deploy and allow_classic_ssh type jobs to go only on nodes
INSERT INTO admission_rules (rule) VALUES ('
my @allowed_resources = ("network_address","switch");
if (grep(/^(deploy|allow_classic_ssh)$/, @{$type_list})){
    foreach my $mold (@{$ref_resource_list}){
        foreach my $r (@{$mold->[0]}){
            my $i = 0;
            while (($i <= $#{@{$r->{resources}}})){
                if (! grep(/^$r->{resources}->[$i]->{resource}$/, @allowed_resources)){
                    die("[ADMISSION RULE] \'$r->{resources}->[$i]->{resource}\' resource is not allowed with a deploy or allow_classic_ssh type job\\n");
                }
                $i++;
            }
        }
    }
}
');

-- Force desktop_computing jobs to go on nodes with the desktop_computing property
INSERT INTO admission_rules (rule) VALUES ('
if (grep(/^desktop_computing$/, @{$type_list})){
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND desktop_computing = \\\'YES\\\'";
    }else{
        $jobproperties = "desktop_computing = \\\'YES\\\'";
    }
}else{
    if ($jobproperties ne ""){
        $jobproperties = "($jobproperties) AND desktop_computing = \\\'NO\\\'";
    }else{
        $jobproperties = "desktop_computing = \\\'NO\\\'";
    }
}
print("[ADMISSION RULE] Added automatically desktop_computing resource constraints\\n");
');


-- How to limit reservation number by user
INSERT INTO admission_rules (rule) VALUES ('
if ($reservationField eq "toSchedule") {
    my $max_nb_resa = 2;
    my $nb_resa = $dbh->do("    SELECT job_id
                                FROM jobs
                                WHERE
                                    job_user = \\\'$user\\\' AND
                                    (reservation = \\\'toSchedule\\\' OR
                                    reservation = \\\'Scheduled\\\') AND
                                    (state = \\\'Waiting\\\' OR
                                     state = \\\'Hold\\\')
             ");
    if ($nb_resa >= $max_nb_resa){
        die("[ADMISSION RULE] Error : you cannot have more than $max_nb_resa waiting reservations.\\n");
    }
}
');

--# How to perform actions if the user name is in a file
--INSERT INTO admission_rules (rule) VALUES ('
--open(FILE, "/tmp/users.txt");
--while (($queue_name ne "admin") and ($_ = <FILE>)){
--    if ($_ =~ m/^\\s*$user\\s*$/m){
--        print("[ADMISSION RULE] Change assigned queue into admin\\n");
--        $queue_name = "admin";
--    }
--}
--close(FILE);
--');

-- Limit walltime for interactive jobs
INSERT INTO admission_rules (rule) VALUES ('
my $max_walltime = iolib::sql_to_duration("12:00:00");
if ($jobType eq "INTERACTIVE"){ 
    foreach my $mold (@{$ref_resource_list}){
        if ((defined($mold->[1])) and ($max_walltime < $mold->[1])){
            print("[ADMISSION RULE] Walltime to big for an INTERACTIVE job so it is set to $max_walltime.\\n");
            $mold->[1] = $max_walltime;
        }
    }
}
');

-- specify the default walltime if it is not specified
INSERT INTO admission_rules (rule) VALUES ('
my $default_wall = iolib::sql_to_duration("2:00:00");
foreach my $mold (@{$ref_resource_list}){
    if (!defined($mold->[1])){
        print("[ADMISSION RULE] Set default walltime to $default_wall.\\n");
        $mold->[1] = $default_wall;
    }
}
');

-- Check if types given by the user are right
INSERT INTO admission_rules (rule) VALUES ('
my @types = ("container","inner","deploy","desktop_computing","besteffort","cosystem","idempotent","timesharing","allow_classic_ssh");
foreach my $t (@{$type_list}){
    my $i = 0;
    while (($types[$i] ne $t) and ($i <= $#types)){
        $i++;
    }
    if (($i > $#types) and ($t !~ /^(timesharing|inner)/)){
        die("[ADMISSION RULE] The job type $t is not handled by OAR; Right values are : @types\\n");
    }
}
');

-- If resource types are not specified, then we force them to default
INSERT INTO admission_rules (rule) VALUES ('
foreach my $mold (@{$ref_resource_list}){
    foreach my $r (@{$mold->[0]}){
        my $prop = $r->{property};
        if (($prop !~ /[\\s\\(]type[\\s=]/) and ($prop !~ /^type[\\s=]/)){
            if (!defined($prop)){
                $r->{property} = "type = \\\'default\\\'";
            }else{
                $r->{property} = "($r->{property}) AND type = \\\'default\\\'";
            }
        }
    }
}
print("[ADMISSION RULE] Modify resource description with type constraints\\n");
');

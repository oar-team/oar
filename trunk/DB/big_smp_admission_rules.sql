# OAR Admission rules for big shared memory computer
# The first rule adds the quantitative concept for the memory property
# The second rule aims to match cpus on physical nodes to prevent
# dispersion of the jobs if the job is of the type "optimize"
# The property "pnode" must have been defined to group resources 
# (cpus) on "pnodes" (physical nodes).


# Memory management rule
insert into admission_rules (rule) values ('

  # Memory of a CPU bank:
  my $memory_bank_size=1947;

  foreach my $mold (@{$ref_resource_list}){
    foreach my $r (@{$mold->[0]}){
      my $i=0;
      my $cpu=0;
      my $cpufound=0;

      # Catch the mem resource
      foreach my $resource (@{$r->{resources}}) {
        if ($resource->{resource} eq "mem") {
          $cpu=int($resource->{value}/$memory_bank_size)+1;
          print "[MEM ADMISSION RULE] Found a mem property that needs $cpu memory bank(s) of $memory_bank_size\n";
          splice (@{$r->{resources}},$i,1);
        }
        $i++;
      }
      $i=0;

      # Catch the cpu resource and modify it if necessary
      foreach my $resource (@{$r->{resources}}) {
        if ("$resource->{resource}" eq "cpu") {
          if ($cpu > $resource->{value}) { 
            $resource->{value}=$cpu; 
            print "[MEM ADMISSION RULE] Adapting cpu number to match memory size banks: cpu=$cpu\n";
          }
          $cpufound=1;
        }
        $i++;
      }

      # If a cpu property doesnt not exist, fix it if necessary
      if ($cpu && !$cpufound) {
         print "[MEM ADMISSION RULE] Adding a cpu resource cpu=$cpu\n";
         my $resource;
         $resource->{resource}="cpu";
         $resource->{value}=$cpu;
         push (@{$r->{resources}},$resource);
      }

      # Print final resources 
      print "[MEM ADMISSION RULE] Real resources: /";
      foreach my $resource (@{$r->{resources}}) {
        print $resource->{resource} ."=". $resource->{value} ."/";
      }
      print "\n";
    }
  }
');


# Physical nodes matching rule
insert into admission_rules (rule) values ('

  # Number of CPU per node
  my $ncpus=2;

  if (grep(/^optimize$/, @{$type_list})){
      print "[OPTIM ADMISSION RULE] optimize type given. Will try to match resources on physical nodes.\n";
      foreach my $mold (@{$ref_resource_list}){
        foreach my $r (@{$mold->[0]}){
          my $pnode_found=0;
          my $cpus=0;
          my $pnodes=0;

          # Search for an already pnode property
          foreach my $resource (@{$r->{resources}}) {
            if ($resource->{resource} eq "pnode") {
              $pnode_found=1;
              print "[OPTIM ADMISSION RULE] A pnode property is already given. Nothing to optimize.\n";
            }
          }

          # Catch the cpu resource and modify it into a pnode resource if possible
          if (!$pnode_found) {
            foreach my $resource (@{$r->{resources}}) {
              if ($resource->{resource} eq "cpu") {
                $cpus=$resource->{value};
                $pnodes=int($cpus/$ncpus);
                if (($pnodes*$ncpus) == $cpus) {
                   print "[OPTIM ADMISSION RULE] Modifing cpu=$cpus into pnode=$pnodes.\n";
                   $resource->{resource}="pnode";
                   $resource->{value}=$pnodes;
                }else {
                   print "[OPTIM ADMISSION RULE] Unable to match $cpus cpus with pnodes of $ncpus cpus each. Nothing optimized.\n";
                }
              }
            }
          }

          # Print final resources
          print "[OPTIM ADMISSION RULE] Real resources: /";
          foreach my $resource (@{$r->{resources}}) {
            print $resource->{resource} ."=". $resource->{value} ."/";
          }
          print "\n";
        }
      }
  } 
');


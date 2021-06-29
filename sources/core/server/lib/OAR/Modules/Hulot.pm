package OAR::Modules::Hulot;
require Exporter;

# This module is responsible of waking up / shutting down nodes
# when the scheduler decides it (writes it on a named pipe)

# CHECK command is sent on the named pipe to Hulot:
#  - by windowForker module:
#      - to avoid zombie process
#      - to messages received in queue (IPC)
#  - by MetaScheduler if there is no node to wake up / shut down in order:
#      - to check timeout and check memorized nodes list <TODO>
#      - to check booting nodes status

#***********************************************
#  [TODO]
# Todo?: Group nodes passed to the sleeping command (to do inside windowforker)
#
#***********************************************

use strict;
use OAR::Conf qw(init_conf get_conf is_conf get_conf_with_default_param);
use POSIX qw(strftime sys_wait_h);
use Time::HiRes qw(gettimeofday);
use OAR::IO;
use OAR::Tools;
use OAR::Modules::Judas
  qw(oar_debug oar_warn oar_error send_log_by_email set_current_log_category);
use OAR::WindowForker;
use IPC::SysV qw(IPC_PRIVATE IPC_RMID IPC_CREAT S_IRUSR S_IWUSR IPC_NOWAIT);

#use Devel::Cycle;
#use Devel::Peek;
use Data::Dumper;

require Exporter;
our ( @ISA, @EXPORT, @EXPORT_OK );
@ISA       = qw(Exporter);
@EXPORT_OK = qw(start_energy_loop);

my $FIFO = "/tmp/oar_hulot_pipe";

# Default values if not specified in oar.conf
my $ENERGY_SAVING_WINDOW_SIZE                 = 25;
my $ENERGY_SAVING_WINDOW_TIME                 = 60;
my $ENERGY_SAVING_WINDOW_TIMEOUT              = 120;
my $ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT = 900;

# Log category
set_current_log_category('Hulot');

# Get OAR configuration
init_conf( $ENV{OARCONFFILE} );
my $remote_host = get_conf("SERVER_HOSTNAME");
my $remote_port = get_conf("SERVER_PORT");

## add_to_hash
# parameters: ref on: source hash, destination hash
sub add_to_hash($$) {
    my $hash_source = shift;
    my $hash_dest   = shift;
    my $tmp;
    foreach $tmp ( keys(%$hash_source) ) {
        @$hash_dest{$tmp} = @$hash_source{$tmp};
    }
}

## change_node_state
# Changes node state
# parameters: base, nodeToChange, StateToSet
# return value: /
# side effects: /
sub change_node_state($$$) {
    my ( $base, $node, $state ) = @_;

    #oar_debug("[Hulot] Changing state of node '$node' to '$state'\n");
    OAR::IO::set_node_nextState( $base, $node, $state );
    OAR::Tools::notify_tcp_socket( $remote_host, $remote_port, "ChState" );
}

## check
# Sends 'check' signal on the named pipe to Hulot
sub check() {
    my @tab = ();
    return send_cmd_to_fifo( \@tab, "CHECK" );
}


##check_reminded_list
# Checks if some nodes in list_to_remind can be processed
# parameters: ref to hash : running list, reminded list and list to process
# return value: /
# side effects: move nodes from reminded list to list to process if it's possible.
sub check_reminded_list($$$) {
    my ( $tmp_list_running, $tmp_list_to_remind, $tmp_list_to_process ) = @_;
    foreach my $rmd_node ( keys(%$tmp_list_to_remind) ) {
        my $tmp_nodeFinded = 0;
        foreach my $run_node ( keys(%$tmp_list_running) ) {
            if ( $rmd_node eq $run_node ) {
                $tmp_nodeFinded = 1;
            }
        }
        if ( $tmp_nodeFinded == 0 ) {

            # move this node from reminded list to list to process
#            oar_debug(
#"[Hulot] Adding '$rmd_node=>$$tmp_list_to_remind{$rmd_node}' to list to process\n"
#            );
            $$tmp_list_to_process{$rmd_node} =
              { 'command' => $$tmp_list_to_remind{$rmd_node}, 'timeout' => -1 };

#            oar_debug(
#                "[Hulot] Removing node '$rmd_node' from list to remember\n");
            remove_from_hash( $tmp_list_to_remind, $rmd_node );
        }
    }
}

## check_returned_cmd
# Checks received messages from WindowForker module
# parameters: base, received messages and ref to hash : running list, reminded list and list to process
# return value: /
# side effects: - Removes halted node from the running list ;
#               - Suspects node if an error is returned by WindowForker module.
sub check_returned_cmd($$$$$) {
    my ( $base, $tmp_message, $tmp_list_running, $tmp_list_to_remind,
        $tmp_list_to_process )
      = @_;

    ( my $tmp_node, my $tmp_cmd, my $tmp_return ) =
      split( /:/, $tmp_message, 3 );
    oar_debug(
"[Hulot] Received from WindowForker : Node=$tmp_node ; Action=$tmp_cmd ; ReturnCode : $tmp_return\n"
    );
    if ( $tmp_return == 0 ) {
        if ( $tmp_cmd eq "HALT" ) {

# Remove halted node from the list running nodes because we don't monitor the turning off
            remove_from_hash( $tmp_list_running, $tmp_node );
        }
    }
    else {

        # Suspect node if error
        change_node_state( $base, $tmp_node, "Suspected" );
        my $str = "[Hulot] Node $tmp_node was suspected because an error occurred with a command launched by Hulot";
        OAR::IO::add_new_event_with_host($base, "LOG_SUSPECTED", 0, $str, [$tmp_node]);
        oar_debug("$str\n");
    }
}

## halt_nodes
sub halt_nodes($) {
    my $nodes = shift;
    return send_cmd_to_fifo( $nodes, "HALT" );
}

## is_exists_in_array
# Returns true if the value exists in the array
# parameters: Value searched, ref on the array
# return value: boolean
# side effects: /
sub is_exists_in_array ( $ $ ) {
    my $value = shift;
    my $array = shift;
    my $res   = 0;
    if ( "@$array" =~ /$value/ ) {
        $res = 1;
    }
    else {
        $res = 0;
    }
    return ($res);
}

## remove_from_array
# Remove a value from an array
# parameters: Reference on an array, value to remove
# return value: None
sub remove_from_array($$) {
    my $array_toclean = shift;
    my $value         = shift;
    my $tmp;
    my @cleaned_array;
    foreach $tmp (@$array_toclean) {
        if ( $tmp ne $value ) {
            @cleaned_array = $tmp;
        }
    }
    @$array_toclean = @cleaned_array;
}

## remove_from_hash
# Remove a value from a hash
# parameters: Reference on a hash, value to remove
# return value: None
sub remove_from_hash($$) {
    my $hash_toclean = shift;
    my $value        = shift;
    my $tmp;
    my %cleaned_hash;
    foreach $tmp ( keys(%$hash_toclean) ) {
        if ( $tmp ne $value ) {
            $cleaned_hash{$tmp} = @$hash_toclean{$tmp};
        }
    }
    %$hash_toclean = %cleaned_hash;
}

## send_cmd_to_fifo
sub send_cmd_to_fifo($$) {
    my $nodes      = shift;
    my $command    = shift;
    my $nodes_list = join( ' ', @$nodes );
    unless ( open( FIFO, "> $FIFO" ) ) {
        oar_error("[Hulot] Could not open the fifo $FIFO!\n");
        return 1;
    }
    print FIFO "$command:$nodes_list\n";
    close(FIFO);
    return 0;
}

## start_energy_loop
sub start_energy_loop() {
    my %nodes_list_to_process;
    my %nodes_list_to_remind;
    my %nodes_list_running;
    my $forker_pid;
    my $id_msg_hulot;
    my $pack_template = "l! a*";
    my $max_cycles=int(get_conf_with_default_param(
                                "ENERGY_MAX_CYCLES_UNTIL_REFRESH",
                                "5000"
                              ));
    my $runtime_directory=get_conf_with_default_param(
                                "OAR_RUNTIME_DIRECTORY",
                                "/tmp/oar_runtime"
                              );
    my %timeouts = fill_timeouts(get_conf_with_default_param(
                       "ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT", 
                       $ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT));
    
    oar_debug("[Hulot] Starting Hulot, the energy saving module\n");
    
    # Load state if exists
    if (-s "$runtime_directory/hulot_status.dump") {
      my $ref = do "$runtime_directory/hulot_status.dump";
      if ($ref) {
        if (defined($ref->[0]) && defined($ref->[1]) &&
            ref($ref->[0]) eq "HASH" && ref($ref->[1]) eq "HASH") {
          oar_debug("[Hulot] State file found, loading it\n");
          %nodes_list_running = %{$ref->[0]};
          %nodes_list_to_remind = %{$ref->[1]};
        }
      }
    }
    unlink "$runtime_directory/hulot_status.dump";

    # Init keepalive values ie construct a hash:
    #      sql properties => number of nodes to keepalive
    # given the ENERGY_SAVING_NODES_KEEPALIVE variable such as:
    # "cluster=paradent:nodes=4,cluster=paraquad:nodes=6"
    my %keepalive;
    # Number of nodes to keepalive per properties:
    #     $keepalive{<properties>}{"min"}=int
    # Number of nodes currently alive and with no jobs, per properties:
    #     $keepalive{<properties>}{"cur_idle"}=int 
    # List of nodes corresponding to properties:
    #     $keepalive{<properties>}{"nodes"}=@;     
    my $keepalive_string=get_conf_with_default_param(
                                "ENERGY_SAVING_NODES_KEEPALIVE",
                                "type='default':0"
                              );
    if (not $keepalive_string =~ /.+:\d+,*/) {
      oar_debug("[Hulot] Syntax error into ENERGY_SAVING_NODES_KEEPALIVE!\n");
      exit(3);
    }else{
      my @keepalive_items=split(/\s*\&\s*/,$keepalive_string);
      foreach my $item (@keepalive_items) {
        (my $properties, my $nodes_number)=split(/:/,$item);
        if (not $nodes_number =~ /^(\d+)$/) {
          oar_error("[Hulot] Syntax error into ENERGY_SAVING_NODES_KEEPALIVE! (not an integer)\n");
          exit(2);
        }
        $keepalive{$properties}=();
        $keepalive{$properties}{"nodes"}=[];
        $keepalive{$properties}{"min"}=$nodes_number;
        oar_debug("[Hulot] Keepalive(". $properties .") => ". $nodes_number ."\n");
      }
    }

    # Creates the fifo if it doesn't exist
    unless ( -p $FIFO ) {
        unlink $FIFO;
        system( 'mknod', '-m', '600', $FIFO, 'p' );
    }

    # Test if the FIFO has been correctly created
    unless ( -p $FIFO ) {
        oar_error("[Hulot] Could not create the fifo $FIFO!\n");
        exit(1);
    }

    # Create message queue for Inter Processus Communication
    $id_msg_hulot = msgget( IPC_PRIVATE, IPC_CREAT | S_IRUSR | S_IWUSR );
    if ( !defined $id_msg_hulot ) {
        oar_error("[Hulot] Cannot create message queue : msgget failed\n");
        exit(1);
    }

    my $count_cycles;

    # Open the fifo
    while (1) {
        unless ( open( FIFO, "$FIFO" ) ) {
            oar_error("[Hulot] Could not open the fifo $FIFO!\n");
            exit(2);
        }

        #debug
        #open(DUMP,">>/tmp/hulot_dump");
        #my $pid=$$;

        # Start to manage commands and nodes comming on the fifo
        while (<FIFO>) {
        #print DUMP "point 1:"; print `ps -p $pid -o rss h >> /tmp/hulot_dump`; 
            my $key;
            my $nodeFinded   = 0;
            my $nodeToAdd    = 0;
            my $nodeToRemind = 0;
            my $rcvd;
            my $type_rcvd;
            my $base = OAR::IO::connect()
              or die("[Hulot] Cannot connect to the database\n");

            if ( msgrcv( $id_msg_hulot, $rcvd, 600, 0, IPC_NOWAIT ) ) {
                ( $type_rcvd, $rcvd ) = unpack( $pack_template, $rcvd );
                check_returned_cmd( $base, $rcvd, \%nodes_list_running,
                    \%nodes_list_to_remind, \%nodes_list_to_process );
                while ( msgrcv( $id_msg_hulot, $rcvd, 600, 0, IPC_NOWAIT ) ) {
                    ( $type_rcvd, $rcvd ) = unpack( $pack_template, $rcvd );
                    check_returned_cmd( $base, $rcvd, \%nodes_list_running,
                        \%nodes_list_to_remind, \%nodes_list_to_process );
                }
            }

            ( my $cmd, my $nodes ) = split(/:/, $_, 2 );
            chomp($nodes);
            my @nodes = split(/ /, $nodes );

            if ( $cmd eq "CHECK" ) {
                oar_debug("[Hulot] Got request '$cmd'\n");
            }
            else {
                oar_debug("[Hulot] Got request '$cmd' for nodes : $nodes\n");
            }

            #print DUMP "point 2:"; print `ps -p $pid -o rss h >> /tmp/hulot_dump`; 

            # Check idle and occupied nodes
            my @all_occupied_nodes=OAR::IO::get_alive_nodes_with_jobs($base);
            my @nodes_that_can_be_waked_up=OAR::IO::get_nodes_that_can_be_waked_up($base,OAR::IO::get_date($base));
            foreach my $properties (keys %keepalive) {
              my @occupied_nodes;
              my @idle_nodes;
              $keepalive{$properties}{"nodes"} =
                 [ OAR::IO::get_nodes_with_given_sql($base,$properties) ];
              $keepalive{$properties}{"cur_idle"}=0;
              foreach my $alive_node (OAR::IO::get_nodes_with_given_sql($base,
                                        $properties. " and (state='Alive' or next_state='Alive')")) {
                if (grep(/^$alive_node$/,@all_occupied_nodes)) {
                  push(@occupied_nodes,$alive_node);
                }else{
                  $keepalive{$properties}{"cur_idle"}+=1;
                  push(@idle_nodes,$alive_node);
                }
              }
              #oar_debug("[Hulot] cur_idle($properties) => "
              #     .$keepalive{$properties}{"cur_idle"}."\n");

              #print DUMP "point 3:"; print `ps -p $pid -o rss h >> /tmp/hulot_dump`; 

              # Wake up some nodes corresponding to properties if needed
              my $ok_nodes=$keepalive{$properties}{"cur_idle"}
                            - $keepalive{$properties}{"min"};
              my $wakeable_nodes=@{$keepalive{$properties}{"nodes"}}
                            - @idle_nodes - @occupied_nodes;
              while ($ok_nodes < 0 && $wakeable_nodes > 0) {
                foreach my $node (@{$keepalive{$properties}{"nodes"}}) {
                  unless (grep(/^$node$/,@idle_nodes) || grep(/^$node$/,@occupied_nodes)) {
                    # we have a good candidate to wake up
                    # now, check if the node has a good status
                    $wakeable_nodes--;
                    if (grep(/^$node$/,@nodes_that_can_be_waked_up)) {
                      $ok_nodes++;
                      # add WAKEUP:$node to list of commands if not already
                      # into the current command list
                      if (not defined($nodes_list_running{$node})) {
                        $nodes_list_to_process{$node} =
                          { 'command' => "WAKEUP", 'timeout' => -1 };
                        oar_debug("[Hulot] Waking up $node to satisfy '$properties' keepalive (ok_nodes=$ok_nodes, wakeable_nodes=$wakeable_nodes)\n");
                      }else{
                         if ($nodes_list_running{$node}->{'command'} ne "WAKEUP") {
                         oar_debug("[Hulot] Wanted to wake up $node to satisfy '$properties' keepalive, but a command is already running on this node. So doing nothing and waiting for the next cycles to converge.\n");
                         }
                      }
                    }
                    last if ($ok_nodes >=0 || $wakeable_nodes <= 0);
                  }
                }
              }
            }
 
            #print DUMP "point 4:"; print `ps -p $pid -o rss h >> /tmp/hulot_dump`; 

            # Retrieve list of nodes having at least one resource Alive
            my @nodes_alive = OAR::IO::get_nodes_with_given_sql($base,"state='Alive'");

            # Checks if some booting nodes need to be suspected
            foreach $key ( keys(%nodes_list_running) ) {
                if ( $nodes_list_running{$key}->{'command'} eq "WAKEUP" ) {
                    if (grep(/^$key$/,@nodes_alive)) {
                        oar_debug(
"[Hulot] Booting node '$key' seems now up, so removing it from running list.\n"
                        );

                        # Remove node from the list running nodes
                        remove_from_hash( \%nodes_list_running, $key );
                    }
                    elsif (time > $nodes_list_running{$key}->{'timeout'}) {
                        change_node_state( $base, $key, "Suspected" );
                        my $str = "[Hulot] Node $key was suspected because it did not wake up before the end of the timeout\n";
                        oar_debug($str);
                        OAR::IO::add_new_event_with_host($base, "LOG_SUSPECTED", 0, $str, [$key]);

                        # Remove suspected node from the list running nodes
                        remove_from_hash( \%nodes_list_running, $key );

# Remove this node from received list (if node is present) because it was suspected
                        remove_from_array( \@nodes, $key );
                    }
                }
            }

            # Check if some nodes in list_to_remind can be processed
            check_reminded_list( \%nodes_list_running, \%nodes_list_to_remind,
                \%nodes_list_to_process );

            # Checking if each couple node/command was already received or not
            foreach my $node (@nodes) {
                $nodeFinded   = 0;
                $nodeToAdd    = 0;
                $nodeToRemind = 0;
                if ( keys(%nodes_list_running) > 0 ) {

                    # Checking
                    foreach $key ( keys(%nodes_list_running) ) {
                        if ( $node eq $key ) {
                            $nodeFinded = 1;
                            if (
                                $cmd ne $nodes_list_running{$key}->{'command'} )
                            {

                        # This node is already planned for an other action
                        # We have to keep in memory this new couple node/command
                                $nodeToRemind = 1;
                            }
                            else {
                                oar_debug(
"[Hulot] Command '$nodes_list_running{$key}->{'command'}' is already running on node '$node' (timeout in ".($nodes_list_running{$key}->{'timeout'} - time)."s)\n"
                                );
                            }
                        }
                    }
                    if ( $nodeFinded == 0 ) {
                        $nodeToAdd = 1;
                    }
                }
                else {
                    $nodeToAdd = 1;
                }

                if ( $nodeToAdd == 1 ) {

                    # Adding couple node/command to the list to process
#                    oar_debug(
#                        "[Hulot] Adding '$node=>$cmd' to list to process\n");
                    $nodes_list_to_process{$node} =
                      { 'command' => $cmd, 'timeout' => -1 };
                }

                if ( $nodeToRemind == 1 ) {

                    # Adding couple node/command to the list to remind
#                    oar_debug(
#                        "[Hulot] Adding '$node=>$cmd' to list to remember\n");
                    $nodes_list_to_remind{$node} = $cmd;
                }
            }
            
            # Creating command list
            my @commandToLaunch = ();
            my @dont_halt;
            my $match=0;
            # Get the timeout taking into account the number of nodes
            # already waking up + the number of nodes to wake up
            my $timeout = get_timeout(\%timeouts, 
                                      scalar keys(%nodes_list_running) +
                                      scalar keys(%nodes_list_to_process));

            foreach $key ( keys(%nodes_list_to_process) ) {
              SWITCH: for ( $nodes_list_to_process{$key}->{'command'} ) {

                    /WAKEUP/ && do {
                        #Save the timeout for the nodes to be processed.
                        $nodes_list_to_process{$key}->{'timeout'} = time + $timeout;
                        push( @commandToLaunch, "WAKEUP:$key" );
                        last;
                    };

                    /HALT/ && do {
                        # Don't halt nodes that needs to be kept alive
                        $match=0;
                        foreach my $properties (keys %keepalive) {
                          my @nodes=@{$keepalive{$properties}{"nodes"}};
                          if (@nodes>0 && grep(/$key/,@nodes)) {
                            if ($keepalive{$properties}{"cur_idle"} 
                                 <= $keepalive{$properties}{"min"}) {
                              oar_debug(
"[Hulot] Not halting '$key' because I need to keep alive ".
$keepalive{$properties}{"min"} ." nodes having '$properties'\n"
                              );
                              $match=1;
                              remove_from_hash(\%nodes_list_running,$key);
                              remove_from_hash(\%nodes_list_to_process,$key);
                            }
                          }
                        }

                        # If the node is ok to be halted
                        unless($match) {
                          # Update the keepalive counts
                          foreach my $properties (keys %keepalive) {
                            my @nodes=@{$keepalive{$properties}{"nodes"}};
                            if (@nodes>0 && grep(/$key/,@nodes)) {
                              $keepalive{$properties}{"cur_idle"}-=1;
                            }
                          }
                          # Change state node to "Absent" and halt it
                          change_node_state( $base, $key, "Absent" );
                          oar_debug(
"[Hulot] Hulot module put node '$key' in energy saving mode (state~Absent)\n"
                          );
                          push( @commandToLaunch, "HALT:$key" );
                        } 
                        last;
                    };

                    oar_error("[Hulot] Unknown command: '".$nodes_list_to_process{$key}->{'command'}."' for node '$key'\n");
                    exit 1;
                }
            }

            OAR::IO::disconnect($base);

            # Launching commands
            if ( $#commandToLaunch >= 0 ) {
                my %forker_type = (
                        "type"     => "Hulot",
                        "id_msg"   => $id_msg_hulot,
                        "template" => $pack_template
                    );
                if (get_conf_with_default_param("ENERGY_SAVING_WINDOW_FORKER_BYPASS", "no") eq "yes") {
                    #Bypassing OAR::WindowForker
                    oar_debug("[Hulot] Launching commands to nodes\n");
                    
                    #Strings that will be passed to wakeup and shutdown commands
                    my @nodesToWakeUp = ();
                    my @nodesToShutDown = ();
                    
                    #Build strings to pass to wakeup and shutdown commands
                    my $base = OAR::IO::connect();
                    foreach my $command ( @commandToLaunch ) {
                        (my $cmd, my $node)=split(/:/,$command, 2);
                        if ( $cmd eq "HALT" ) {
                            push(@nodesToShutDown, $node);
                            OAR::IO::add_new_event_with_host($base,"HALT_NODE",0,"Node $node halt request",[$node]);
                        }
                        elsif ( $cmd eq "WAKEUP" ) {
                            push(@nodesToWakeUp, $node);
                            OAR::IO::add_new_event_with_host($base,"WAKEUP_NODE",0,"Node $node wake-up request",[$node]);
                        }
                    }
                    OAR::IO::disconnect($base);
                    execute_action(get_conf("ENERGY_SAVING_NODE_MANAGER_WAKE_UP_CMD"), \@nodesToWakeUp, "WAKEUP", \%forker_type);
                    execute_action(get_conf("ENERGY_SAVING_NODE_MANAGER_SLEEP_CMD"), \@nodesToShutDown, "HALT", \%forker_type);
                }
                else {
                    # Use the window forker to execute commands in parallel
                    oar_debug(
    "[Hulot] Launching commands to nodes by using WindowForker\n"
                    );

                    # fork in order to don't block the pipe listening
                    $forker_pid = fork();
                    if ( defined($forker_pid) ) {
                        if ( $forker_pid == 0 ) {
                            ( my $t, my $y ) = OAR::WindowForker::launch(
                                \@commandToLaunch,
                                get_conf_with_default_param(
                                    "ENERGY_SAVING_WINDOW_SIZE",
                                    $ENERGY_SAVING_WINDOW_SIZE
                                ),
                                get_conf_with_default_param(
                                    "ENERGY_SAVING_WINDOW_TIME",
                                    $ENERGY_SAVING_WINDOW_TIME
                                ),
                                get_conf_with_default_param(
                                    "ENERGY_SAVING_WINDOW_TIMEOUT",
                                    $ENERGY_SAVING_WINDOW_TIMEOUT
                                ),
                                0,
                                \%forker_type
                            );
                            exit 0;
                        }
                    }
                    else {
                        oar_error("[Hulot] Fork system call failed\n");
                    }
                }
            }

            # Check child endings
            while ( ( $forker_pid = waitpid( -1, WNOHANG ) ) > 0 ) {
                register_wait_results( $forker_pid, $? );
            }

            # Adds to running list last new launched commands
            add_to_hash( \%nodes_list_to_process, \%nodes_list_running );

            # Cleaning the list to process
            %nodes_list_to_process = ();

            # Suicide to workaround memory leaks. Almighty will restart hulot.
            $count_cycles++;
            if ($count_cycles > $max_cycles) {
              oar_warn("[Hulot] Reached $max_cycles cycles. Suiciding (place aux jeunes).\n");
              # cleaning ipc
              shmctl($id_msg_hulot, IPC_RMID, 0); # <- doesn't work... why??
              # saving state
              if (open(FILE,">$runtime_directory/hulot_status.dump")) {
                # removing HALT commands from state file as we don't check timeout on that
                foreach my $node ( keys(%nodes_list_running) ) {
                  if ($nodes_list_running{$node}->{'command'} eq "HALT") {
                    remove_from_hash( \%nodes_list_running, $node );
                  }
                }
                print FILE Dumper([\%nodes_list_running,\%nodes_list_to_remind]);
              }else{
                oar_error("[Hulot] could not open $runtime_directory/hulot_status.dump for writing!");
              }
              close(FIFO);
              unlink $FIFO;
              exit(42);
            }
        }
        close(FIFO);
        # Unfortunately, never reached:
        shmctl($id_msg_hulot, IPC_RMID, 0);
    }
}

sub execute_action($$$$) {
    my ($command, $nodes, $cmd, $type) = @_;
    my %forker_type = %$type;
    if ($#{$nodes} >= 0) {
        my $command_to_exec = "echo \"" . join(" ", @{$nodes}) . "\" | " . $command;
        print $command_to_exec . " \n";
        my $forker_pid = fork();
        if ( defined($forker_pid) ) {
            if ( $forker_pid == 0 ) {
                system($command_to_exec);
                foreach my $node ( @{$nodes} ) {
                    if (!msgsnd($forker_type{"id_msg"}, pack($forker_type{"template"}, 1, "$node:$cmd:".$?), IPC_NOWAIT)){
                        oar_error("[Hulot] Failed to send message by msgsnd(): $!\n");
                    }
                }
                exit 0;
            }
        }
        else {
            oar_error("[Hulot] Fork system call failed, command \"" . 
                $command_to_exec . "\" not executing\n");
        }
    }
}

# Treate finished processes
sub register_wait_results($$) {
    my ( $pid, $return_code ) = @_;

    my $exit_value  = $return_code >> 8;
    my $signal_num  = $return_code & 127;
    my $dumped_core = $return_code & 128;
    if ( $pid > 0 ) {

#oar_debug("[DEBUG-HULOT] Child process $pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n");
    }
}

## wake_up_nodes
sub wake_up_nodes($) {
    my $nodes = shift;
    return send_cmd_to_fifo( $nodes, "WAKEUP" );
}

#Fill the timeouts hash with the different timeouts
sub fill_timeouts ($) {
    my $string = shift;
    my %timeouts = ();
    
    # test if the timeout is a simple duration in seconds
    if ($string =~ /^\s*\d+\s*$/ ){
        $timeouts{1} = int($string);
    }
    else {
        #Remove front spaces
        $string =~ s/^\s+//;
        #Values must be separated by non-printable characters
        my @words = split( /\s+/, $string);
        my @vals = ();
        foreach my $couple (@words) {
            #Each couple of values is only composed of digits separated by
            if ($couple =~ /^\d+:\d+$/) {
                @vals = split(/:/, $couple);
                $timeouts{$vals[0]} =  $vals[1];
            }
            else {
                oar_warn("[Hulot] \"$couple\" is not a valid couple for a timeout\n");
            }
        }
    }
    
    #If no good value has been found, use the default one
    if ( keys( %timeouts ) == 0) {
        $timeouts{1} = $ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT;
        oar_warn("[Hulot] Timeout not properly defined, using default value: 
                     $ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT\n");
    }
    
    return %timeouts;
}

#Choose a timeout based on the number of nodes to wake up
sub get_timeout($$) {
    my ($timeouts, $nb_nodes) = @_;
    my $timeout = $ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT;
    $timeout = @$timeouts{1} if (defined(@$timeouts{1}));
    
    #Search for the timeout of the corresponding interval
    foreach my $tmp ( sort { $a <=> $b } keys( %$timeouts ) ) {
        last if ($nb_nodes < $tmp);
        $timeout = @$timeouts{$tmp};
    }
    
    oar_debug("[Hulot] Waking up $nb_nodes nodes: chosen timeout is ".$timeout."s\n");
    return $timeout;
}

return (1);

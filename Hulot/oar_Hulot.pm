package oar_Hulot;
require Exporter;
# This module is responsible of waking up / shutting down nodes
# when the scheduler decides it (writes it on a named pipe)

# CHECK command is sent on the named pipe to Hulot : 
#  - by windowForker module
#      - to avoid zombie process
#      - to messages received in queue (IPC)
#  - by MetaScheduler if there is no node to wake up / shut down in order to check timeout and check memorized nodes list <TODO>

use strict;
use oar_conflib qw(init_conf get_conf is_conf get_conf_with_default_param);
use POSIX qw(strftime sys_wait_h);
use Time::HiRes qw(gettimeofday);
use oar_iolib;
use oar_Tools;
use oar_Judas qw(oar_debug oar_warn oar_error send_log_by_email set_current_log_category);
use window_forker;
use IPC::SysV qw(IPC_PRIVATE IPC_RMID IPC_CREAT S_IRUSR S_IWUSR IPC_NOWAIT);

use Data::Dumper;

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(start_energy_loop);

my $FIFO="/tmp/oar_hulot_pipe";

# Default values if not specified in oar.conf
my $ENERGY_SAVING_WINDOW_SIZE=25;
my $ENERGY_SAVING_WINDOW_TIME=60;
my $ENERGY_SAVING_WINDOW_TIMEOUT=120;
my $ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT=900;


# Log category
set_current_log_category('Hulot');

# Get OAR configuration
init_conf($ENV{OARCONFFILE});
my $remote_host = get_conf("SERVER_HOSTNAME");
my $remote_port = get_conf("SERVER_PORT");


## add_to_hash
# parameters: ref on: source hash, destination hash
sub add_to_hash($$){
	my $hash_source = shift;
	my $hash_dest = shift;
	my $tmp;
	foreach $tmp (keys(%$hash_source)){
		@$hash_dest{$tmp} = @$hash_source{$tmp};
	}
}


## change_node_state
# Changes node state
# parameters: base, nodeToChange, StateToSet
# return value: /
# side effects: /
sub change_node_state($$$){
	my ($base, 
				$node,
				$state) = @_;
	#oar_debug("[Hulot] Changing state of node '$node' to '$state'\n");
	iolib::set_node_nextState($base,$node,$state);
	oar_Tools::notify_tcp_socket($remote_host,$remote_port,"ChState");
}


## check_keepalive_nodes
sub check_keepalive_nodes() {
  # TODO
  # function to be used by almighty, using ENERGY_SAVING_NODES_KEEPALIVE, select nodes to
  # wake up and send them to the pipe (wake_up_nodes($nodes))
  return 0;
}


##check_reminded_list
# Checks if some nodes in list_to_remind can be processed
# parameters: ref to hash : running list, reminded list and list to process
# return value: /
# side effects: move nodes from reminded list to list to process if it's possible.
sub check_reminded_list($$$){
	my ($tmp_list_running,
			$tmp_list_to_remind, 
			$tmp_list_to_process) = @_;
	foreach my $rmd_node (keys(%$tmp_list_to_remind)){
		my $tmp_nodeFinded=0;
		foreach my $run_node (keys(%$tmp_list_running)){
			if($rmd_node eq $run_node){
				$tmp_nodeFinded=1;
			}
		}
		if ($tmp_nodeFinded==0){
			# move this node from reminded list to list to process
			oar_debug("[Hulot] Adding '$rmd_node=>$$tmp_list_to_remind{$rmd_node}' to list to process\n");
			$$tmp_list_to_process{$rmd_node} = {'command' => $$tmp_list_to_remind{$rmd_node}, 'time' => time};
			
			oar_debug("[Hulot] Removing node '$rmd_node' from list to remember\n");
			remove_from_hash($tmp_list_to_remind,$rmd_node);
		}
	}
}


## check_returned_cmd
# Checks received messages from WindowForker module
# parameters: base, received messages and ref to hash : running list, reminded list and list to process
# return value: /
# side effects: - Removes halted node from the running list ;
#               - Suspects node if an error is returned by WindowForker module.
sub check_returned_cmd($$$$$){
	my ($base,
			$tmp_message, 
			$tmp_list_running,
			$tmp_list_to_remind,
			$tmp_list_to_process) = @_;
	
	(my $tmp_node, my $tmp_cmd, my $tmp_return)=split(/:/,$tmp_message,3);
	oar_debug("[Hulot] Received from WindowForker : Node=$tmp_node ; Action=$tmp_cmd ; ReturnCode : $tmp_return\n");
	if ($tmp_return == 0){
		if ($tmp_cmd eq "HALT"){
			# Remove halted node from the list running nodes because we don't monitor the turning off
			remove_from_hash($tmp_list_running,$tmp_node);
		}
	}else{
		# Suspect node if error
		change_node_state($base,$tmp_node,"Suspected");
		oar_debug("[Hulot] Node '$tmp_node' was suspected because an error occurred with a command launched by Hulot\n");
	}
}


## halt_nodes
sub halt_nodes($) {
  my $nodes=shift;
  return send_cmd_to_fifo($nodes,"HALT");
}


## remove_from_array
# Remove a value from an array
# parameters: Reference on an array, value to remove
# return value: None
sub remove_from_array($$){
	my $array_toclean = shift;
	my $value = shift;
	my $tmp;
	my @cleaned_array;
	foreach $tmp (@$array_toclean){
		if($tmp ne $value){
			@cleaned_array = $tmp;
		}
	}
	@$array_toclean=@cleaned_array;
}


## remove_from_hash
# Remove a value from a hash
# parameters: Reference on a hash, value to remove
# return value: None
sub remove_from_hash($$){
	my $hash_toclean = shift;
	my $value = shift;
	my $tmp;
	my %cleaned_hash;
	foreach $tmp (keys(%$hash_toclean)){
		if($tmp ne $value){
			$cleaned_hash{$tmp} = @$hash_toclean{$tmp};
		}
	}
	%$hash_toclean=%cleaned_hash;
}


## send_cmd_to_fifo
sub send_cmd_to_fifo($$) {
  my $nodes=shift;
  my $command=shift;
  my $nodes_list=join(' ',@$nodes);
  unless (open(FIFO, "> $FIFO")) {
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
	my $pack_template="l! a*";
	

	
	oar_debug("[Hulot] Starting Hulot, the energy saving module\n");
	
  # Creates the fifo if it doesn't exist
  unless (-p $FIFO) {
		unlink $FIFO;
		system('mknod', '-m','600',$FIFO,'p');
	}

  # Test if the FIFO has been correctly created
  unless (-p $FIFO) { 
		oar_error("[Hulot] Could not create the fifo $FIFO!\n");
		exit(1);
	}
	
	# Create message queue for Inter Processus Communication
	$id_msg_hulot = msgget(IPC_PRIVATE, IPC_CREAT | S_IRUSR | S_IWUSR);
	if (!defined $id_msg_hulot) {
		oar_error("[Hulot] Cannot create message queue : msgget failed\n");
		exit(1);
	}
	
	# Open the fifo
	while(1){
		unless (open (FIFO, "$FIFO")) {
			oar_error("[Hulot] Could not open the fifo $FIFO!\n");
      exit(2);
		}
		
    # Start to manage commands and nodes comming on the fifo
		while (<FIFO>) {
			my $key;
			my $nodeFinded=0;
			my $nodeToAdd=0;
			my $nodeToRemind=0;
			my $rcvd;
			my $type_rcvd;
			
			my $base = iolib::connect() or die("[Hulot] Cannot connect to the database\n");
			
			if (msgrcv($id_msg_hulot, $rcvd, 600, 0, IPC_NOWAIT)) {
				($type_rcvd, $rcvd) = unpack($pack_template, $rcvd);
				check_returned_cmd($base, $rcvd, \%nodes_list_running, \%nodes_list_to_remind, \%nodes_list_to_process);
				while (msgrcv($id_msg_hulot, $rcvd, 600, 0, IPC_NOWAIT)){
					($type_rcvd, $rcvd) = unpack($pack_template, $rcvd);
					check_returned_cmd($base, $rcvd, \%nodes_list_running, \%nodes_list_to_remind, \%nodes_list_to_process);
				}
			}
			
			(my $cmd, my $nodes)=split(/:/,$_,2);
			chomp($nodes);
      my @nodes=split(/ /,$nodes);
			
			#TODO: SMART wake up / shutdown of the nodes
      # - [Done] Wake up by groups (50 nodes, sleep... 50 nodes, sleep...)
      # - [Done] Don't send the wake up command if it has already been sent for a given node
      # - [Done] Suspect node if wake up requested and not alive since ENERGY_SAVING_NODE_MANAGER_TIMEOUT
      # - Don't shut down nodes depending on ENERGY_SAVING_NODES_KEEPALIVE variable
			# - [Done] Launch commands in background task in order to not block the scheduler (by using fork in the windowForker -> ok) -> OK
			# - [Done] Call windowForker in a fork ? in order to not block the pipe listening 
			#      -> (Sinon Hulot attend que windowForker rende la main -> temps long si bcp de commande car bcp de fenetre a executer)
      #
			# - [Done] Pour la mise en standBy, mettre le noeud "absent" avant de lancer la commande d'exctinction (pour que rien de soit scheduler dessus)
			#
			# - [Done]  Extinction d'un noeud : 
			#				1/ Change node state to Absent 
			#				2/ Execute poweroff command
			#				3/ On regarde le code de retour du script appele pour eteindre et si erreur alors on suspect le noeud
			#				Sinon si pas d'erreur pas de check avec un timeout pour suspecter l'extinction
			#				4/ Puis enlever ce noeud de %nodes_list_running 
			#
			# -- si on passe le noeud à suspected parce qu'on arrive pas à le réveiller : on fait quoi du job
      
      # TODO
      # - Signal CHECK sent by MetaScheduler if there is no node to wake up / shut down in order to check timeout and check memorized nodes list
      # - Check booting nodes periodically and remove them from running list once they are up (else they will be suspected by hulot after the timeout).
			#
      
			oar_debug("[Hulot] Got request '$cmd' for nodes : $nodes\n");
      
      #oar_debug("[DEBUG-HULOT] Dumper de nodes_list_running = ".Dumper(\%nodes_list_running)."\n");
			#oar_debug("[DEBUG-HULOT] Dumper de nodes_list_to_process = ".Dumper(\%nodes_list_to_process)."\n");
			#oar_debug("[DEBUG-HULOT] Dumper de nodes_list_to_remind = ".Dumper(\%nodes_list_to_remind)."\n");
			
			# Checks if some booting nodes need to be suspected
			foreach $key (keys(%nodes_list_running)){
				if ($nodes_list_running{$key}->{'command'} eq "WAKEUP") {
					if(time > ($nodes_list_running{$key}->{'time'} + get_conf_with_default_param("ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT", $ENERGY_SAVING_NODE_MANAGER_WAKEUP_TIMEOUT))){
						change_node_state($base,$key,"Suspected");
						oar_debug("[Hulot] Node '$key' was suspected because it didn't wake up before the end of the timeout\n");
						
						# Remove suspected node from the list running nodes
						remove_from_hash(\%nodes_list_running,$key);
						
						# Remove this node from received list (if node is present) because it was suspected
						remove_from_array(\@nodes,$key);
						#oar_debug("[DEBUG-HULOT] Apres remove_from_array | nodes = ".Dumper(\@nodes)."\n");
					}
				}
			}
      
      # Check if some nodes in list_to_remind can be processed
      check_reminded_list(\%nodes_list_running, \%nodes_list_to_remind, \%nodes_list_to_process);
			
			# Checking if each couple node/command was already received or not
			foreach my $node (@nodes){
				$nodeFinded=0;
				$nodeToAdd=0;
				$nodeToRemind=0;
				if (keys(%nodes_list_running)>0){
					# Checking
					foreach $key (keys(%nodes_list_running)){
						if($node eq $key){
							$nodeFinded=1;
							if ($cmd ne $nodes_list_running{$key}->{'command'}){
								# This node is already planned for an other action
								# We have to keep in memory this new couple node/command
								$nodeToRemind=1;
							}else{
                oar_debug("[Hulot] Command '$nodes_list_running{$key}->{'command'}' is already running on node '$node'\n");
              }
						}
					}
					if ($nodeFinded==0){
						$nodeToAdd=1;
					}
				}else{
					$nodeToAdd=1;
				}
				
				if ($nodeToAdd==1){
					# Adding couple node/command to the list to process
					oar_debug("[Hulot] Adding '$node=>$cmd' to list to process\n");
					$nodes_list_to_process{$node} = {'command' => $cmd, 'time' => time};
				}
				
				if ($nodeToRemind==1){
					# Adding couple node/command to the list to remind
					oar_debug("[Hulot] Adding '$node=>$cmd' to list to remember\n");
					$nodes_list_to_remind{$node} = $cmd;
				}
			}
			
			my @commandToLaunch = ();
			
			foreach $key (keys(%nodes_list_to_process)){
				SWITCH: for ($nodes_list_to_process{$key}->{'command'}) {
					/WAKEUP/ && do {
						#print("[DEBUG-HULOT] [WAKEUP] Node/Command : ".$key."/".$nodes_list_to_process{$key}->{'command'}."\n");
						push (@commandToLaunch, "WAKEUP:$key");
						last; 
					};
					/HALT/ && do {
						# Change state node to "Absent"
						change_node_state($base,$key,"Absent");
						oar_debug("[Hulot] Hulot module put node '$key' in energy saving mode (state~Absent)\n");
            
						#print("[DEBUG-HULOT] [HALT] Node/Command : ".$key."/".$nodes_list_to_process{$key}->{'command'}."\n");
						push (@commandToLaunch, "HALT:$key");
						last; 
					};
					oar_error("[Hulot] Error during commands producing\n");
					exit 1;
				}
			}
			
			iolib::disconnect($base);
			
      # Launching commands
			if ($#commandToLaunch >= 0){
        oar_debug("[Hulot] Launching commands to nodes by using WindowForker\n");
				# fork in order to don't block the pipe listening 
				$forker_pid = fork();
				if (defined($forker_pid)){
					if ($forker_pid == 0){
						my %forker_type = ("type" => "Hulot",
							"id_msg" => $id_msg_hulot,
							"template" => $pack_template);
						
						(my $t, my $y) = window_forker::launch(\@commandToLaunch,
													get_conf_with_default_param("ENERGY_SAVING_WINDOW_SIZE", $ENERGY_SAVING_WINDOW_SIZE),
													get_conf_with_default_param("ENERGY_SAVING_WINDOW_TIME", $ENERGY_SAVING_WINDOW_TIME),
													get_conf_with_default_param("ENERGY_SAVING_WINDOW_TIMEOUT", $ENERGY_SAVING_WINDOW_TIMEOUT),
													0,
													\%forker_type);
						exit 0;
					}
				}else{
					oar_error("[Hulot] Fork system call failed\n");
				}
			}
			
			# Check child endings
			while(($forker_pid = waitpid(-1, WNOHANG)) > 0) {
				register_wait_results($forker_pid, $?);
			}
			
			# Adds to running list last new launched commands
			add_to_hash(\%nodes_list_to_process, \%nodes_list_running);
			
			# Cleaning the list to process
			%nodes_list_to_process = ();
    }
		close(FIFO);
  }
}


# Treate finished processes
sub register_wait_results($$){
    my ($pid,
        $return_code) = @_;
    
    my $exit_value = $return_code >> 8;
    my $signal_num  = $return_code & 127;
    my $dumped_core = $return_code & 128;
    if ($pid > 0){
			#oar_debug("[DEBUG-HULOT] Child process $pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n");
		}  
}


## wake_up_nodes
sub wake_up_nodes($) {
  my $nodes=shift;
  return send_cmd_to_fifo($nodes,"WAKEUP");
}

return(1);

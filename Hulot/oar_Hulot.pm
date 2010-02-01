package oar_Hulot;
require Exporter;
# This module is responsible of waking up / shutting down nodes
# when the scheduler decides it (writes it on a named pipe)

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
				oar_debug("[DEBUG-HULOT] [check_reminded_list] --Finded node $rmd_node-- (rmd_node:$rmd_node = run_node:$run_node)\n");
				#if ($cmd eq $nodes_list_running{$node}){
					## Couple node/command is already planned, so we don't need to add it.
					## We have to keep in memory this new command";
					#$nodeFinded=1;
				#}
			}
		}
		if ($tmp_nodeFinded==0){
			# move this node from reminded list to list to process
			# $nodes_list_to_remind{$node}
			oar_debug("\n\n**********\n\n[DEBUG-HULOT] [check_reminded_list] Dumper de nodes_list_running = ".Dumper($tmp_list_running)."\n");
			oar_debug("[DEBUG-HULOT] [check_reminded_list] Dumper de nodes_list_to_remind = ".Dumper($tmp_list_to_remind)."\n");
			oar_debug("[DEBUG-HULOT] [check_reminded_list] Dumper de nodes_list_to_process = ".Dumper($tmp_list_to_process)."\n\n**********\n\n");
			oar_debug("\n----------\n A copier dans list_to_process: Node:$rmd_node ; Cmd:$$tmp_list_to_remind{$rmd_node}\n--------\n");
			
			oar_debug("[DEBUG-HULOT] Adding to nodes_list_to_process '$rmd_node=>$$tmp_list_to_remind{$rmd_node}'\n");
			$$tmp_list_to_process{$rmd_node} = {'command' => $$tmp_list_to_remind{$rmd_node}, 'time' => time};
			
			oar_debug("[DEBUG-HULOT] Removing node '$rmd_node' from nodes_list_to_remind\n");
			remove_from_hash($tmp_list_to_remind,$rmd_node);
		}
	}
}


## check_returned_cmd
sub check_returned_cmd($$$$$){
	my ($base,
			$tmp_message, 
			$tmp_list_running,
			$tmp_list_to_remind,
			$tmp_list_to_process) = @_;
	my $flag = 0;
	
	(my $tmp_node, my $tmp_cmd, my $tmp_return)=split(/:/,$tmp_message,3);
	oar_debug("\n\n**********\n\n[Hulot] [check_returned_cmd] Received : Node=$tmp_node ; CMD=$tmp_cmd ; Return : $tmp_return\n");
	oar_debug("[DEBUG-HULOT] Dumper de nodes_list_running = ".Dumper($tmp_list_running)."\n");
	oar_debug("[DEBUG-HULOT] Dumper de nodes_list_to_remind = ".Dumper($tmp_list_to_remind)."\n\n**********\n\n");
	if ($tmp_return == 0){
		if ($tmp_cmd eq "HALT"){
			# Remove halted node from the list running nodes because we don't monitor the turning off
			remove_from_hash($tmp_list_running,$tmp_node);
			$flag = 1;
		}
	}else{
		# Suspect node if error
		change_node_state($base,$tmp_node,"Suspected");
		oar_debug("[Hulot] Node '$tmp_node' was suspected because an error occurred with a command launched by Hulot\n");
		$flag = 1;
	}
	
	# Check if nodes in list_to_remind can be processed
	if ($flag == 1){
		check_reminded_list($tmp_list_running, $tmp_list_to_remind, $tmp_list_to_process);
	}
	# Si suspition et/ou retré de la running_liste, regarder si qqch à lancer dans list_to_remind
	
	oar_debug("[DEBUG-HULOT] Dumper de nodes_list_running = ".Dumper($tmp_list_running)."\n");
	oar_debug("[DEBUG-HULOT] Dumper de nodes_list_to_remind = ".Dumper($tmp_list_to_remind)."\n");
}


## halt_nodes
sub halt_nodes($) {
  my $nodes=shift;
  return send_cmd_to_fifo($nodes,"HALT");
}


# Not used ! #
## is_exists_in_array
# Returns true if the value exists in the array
# parameters: Value searched, ref on the array
# return value: boolean
# side effects: /
sub is_exists_in_array ( $ $ ){
	my $value = shift;
  my $array = shift;
	my $res=0;
	if ( "@$array" =~ /$value/) {
		$res=1;
	} else {
		$res=0;
	} 
	return ($res)
}


# Not used ? #
## launch_command
# Send commands to execute to the window forker module.
# parameters: Reference on an array containing commands to execute
# return value: references of 2 hashs
#sub launch_command($){
	#my $commands = shift;
	#(my $finished_processes, my $process_duration) = window_forker::launch($commands,
											#get_conf_with_default_param("ENERGY_SAVING_WINDOW_SIZE", $ENERGY_SAVING_WINDOW_SIZE),
											#get_conf_with_default_param("ENERGY_SAVING_WINDOW_TIME", $ENERGY_SAVING_WINDOW_TIME),
											#get_conf_with_default_param("ENERGY_SAVING_WINDOW_TIMEOUT", $ENERGY_SAVING_WINDOW_TIMEOUT),
											#0,
											#"Hulot");
	#return($finished_processes, $process_duration);
#}


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
		print("\n\n\n[DEBUG-HULOT] En attente de commandes sur le pipe ...\n");
		
		
    # Start to manage commands and nodes comming on the fifo
		while (<FIFO>) {
			my $key;
			my $nodeFinded=0;
			my $nodeToAdd=0;
			my $nodeToRemind=0;
			my $rcvd;
			my $type_rcvd;
			
			my $base = iolib::connect() or die("[Hulot] Cannot connect to the database\n");
			
			
			# CHECK command is : 
			#  - sent by windowForker module to Hulot to avoid zombie process.
			#  - ...
			if($_ eq "CHECK"){
				oar_debug("[Hulot] Received CHECK command on the named pipe ! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>\n");	
			}else{
				oar_debug("[Hulot] Received energy command on the named pipe ! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<>\n");	
			}
			
			if (msgrcv($id_msg_hulot, $rcvd, 600, 0, IPC_NOWAIT)) {
				($type_rcvd, $rcvd) = unpack($pack_template, $rcvd);
				check_returned_cmd($base, $rcvd, \%nodes_list_running, \%nodes_list_to_remind, \%nodes_list_to_process);
				oar_debug("\n\n[Hulot] Received message \'$rcvd\' ; type \'$type_rcvd\' at ".time()." ! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n\n");
				while (msgrcv($id_msg_hulot, $rcvd, 600, 0, IPC_NOWAIT)){
					($type_rcvd, $rcvd) = unpack($pack_template, $rcvd);
					check_returned_cmd($base, $rcvd, \%nodes_list_running, \%nodes_list_to_remind, \%nodes_list_to_process);
					oar_debug("\n\n[Hulot] Received message \'$rcvd\' ; type \'$type_rcvd\' at ".time()." ! <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<\n\n");
				}
			}else{
				oar_debug("[Hulot][MSG] Nothing received\n");
			}
			
			(my $cmd, my $nodes)=split(/:/,$_,2);
			chomp($nodes);
      my @nodes=split(/ /,$nodes);
			
			#TODO: SMART wake up / shutdown of the nodes
      # - Wake up by groups (50 nodes, sleep... 50 nodes, sleep...)
      # - Don't send the wake up command if it has already been sent for a given node
      # - Suspect node if wake up requested and not alive since ENERGY_SAVING_NODE_MANAGER_TIMEOUT
      # - Don't shut down nodes depending on ENERGY_SAVING_NODES_KEEPALIVE variable
			# - Launch commands in background task in order to not block the scheduler (by using fork in the windowForker -> ok) -> OK
			# - Call windowForker in a fork ? in order to not block the pipe listening 
			#		-> (Sinon Hulot attend que windowForker rende la main -> temps long si bcp de commande car bcp de fenetre a executer)
      #
			# -- Pour la mise en standBy, mettre le noeud "absent" avant de lancer la commande d'exctinction (pour que rien de soit scheduler dessus)
			#
			# -- Extinction d'un noeud : 
			#				1/ Change node state to Absent 
			#				2/ Execute poweroff command
			#				3/ On regarde le code de retour du script appele pour eteindre et si erreur alors on suspect le noeud
			#				Sinon si pas d'erreur pas de check avec un timeout pour suspecter l'extinction
			#				4/ Puis enlever ce noeud de %nodes_list_running 
			#
			# -- si on passe le noeud à suspected parce qu'on arrive pas à le réveiller : on fait quoi du job
			
			
			oar_debug("[Hulot] Got request '$cmd' for nodes : $nodes\n");
			
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
			
			#print "[DEBUG-HULOT] Dumper de nodes_list_running = ".Dumper(\%nodes_list_running)."\n";
			#print "[DEBUG-HULOT] Dumper de nodes_list_to_process = ".Dumper(\%nodes_list_to_process)."\n";
			#print "[DEBUG-HULOT] Dumper de nodes_list_to_remind = ".Dumper(\%nodes_list_to_remind)."\n";
			
			# Checking if each couple node/command was already received or not
			foreach my $node (@nodes){
				print "[DEBUG-HULOT] ### -> Node $node\n";
				$nodeFinded=0;
				$nodeToAdd=0;
				$nodeToRemind=0;
				if (keys(%nodes_list_running)>0){
					# Checking
					foreach $key (keys(%nodes_list_running)){
						if($node eq $key){
							$nodeFinded=1;
							print "[DEBUG-HULOT] --Finded node $node-- (node:$node = key:$key)\n";
							#if ($cmd eq $nodes_list_running{$node}){
								## Couple node/command is already planned, so we don't need to add it.
								## We have to keep in memory this new command";
								#$nodeFinded=1;
							#}
							if ($cmd ne $nodes_list_running{$key}->{'command'}){
								# This node is already planned for an other action.
								# We have to keep in memory this new couple node/command";
								#$nodeFinded=1;
								$nodeToRemind=1;
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
					print "[DEBUG-HULOT] Adding to nodes_list_to_process ($node=>$cmd)\n";
					#$nodes_list_to_process{$node} = $cmd;
					#$tmp_hash_of_hash{$node} = {'command' => $cmd, 'time' => time};
					$nodes_list_to_process{$node} = {'command' => $cmd, 'time' => time};
				}
				
				if ($nodeToRemind==1){
					# Adding couple node/command to the list to remind
					print "[DEBUG-HULOT] Adding to nodes_list_to_remind ($node=>$cmd)\n";
					$nodes_list_to_remind{$node} = $cmd;
				}
			}
			
			#print "[DEBUG-HULOT] Dumper de nodes_list_running = ".Dumper(\%nodes_list_running)."\n";
			#print "[DEBUG-HULOT] Dumper de nodes_list_to_process = ".Dumper(\%nodes_list_to_process)."\n";
			#print "[DEBUG-HULOT] Dumper de nodes_list_to_remind = ".Dumper(\%nodes_list_to_remind)."\n";
			
			my @commandToLaunch = ();
			
			foreach $key (keys(%nodes_list_to_process)){
				SWITCH: for ($nodes_list_to_process{$key}->{'command'}) {
					/WAKEUP/ && do {
						# ENERGY_SAVING_NODE_MANAGER_WAKE_UP_CMD
						print("[DEBUG-HULOT] [WAKEUP] Node/Command : ".$key."/".$nodes_list_to_process{$key}->{'command'}."\n");
						#push (@commandToLaunch, "echo \"`date +%T` : Commande node : ".$key."/".$nodes_list_to_process{$key}->{'command'}." \" >> /tmp/oar_hulot_LaunchedCommands ; sleep 30 ; echo \"`date +%T` : [FIN] Commande node : ".$key."/".$nodes_list_to_process{$key}->{'command'}." \" >> /tmp/oar_hulot_LaunchedCommands");
						push (@commandToLaunch, "WAKEUP:$key");
						last; 
					};
					/HALT/ && do {
						# Change state node to "Absent"
						print("\n[DEBUG-HULOT] [HALT] Debut mise a 'Absent' du noeud : ".$key."\n");
						change_node_state($base,$key,"Absent");
						#iolib::set_node_nextState($base,$key,"Absent");
						#oar_Tools::notify_tcp_socket($remote_host,$remote_port,"ChState");
						oar_debug("[Hulot] Hulot module put node '$key' in energy saving mode (~Absent)\n");
						print("[DEBUG-HULOT] [HALT] Fin mise a 'Absent' du noeud : ".$key."\n");
												
						# ENERGY_SAVING_NODE_MANAGER_SLEEP_CMD
						print("[DEBUG-HULOT] [HALT] Node/Command : ".$key."/".$nodes_list_to_process{$key}->{'command'}."\n");
						#push (@commandToLaunch, "echo \"`date +%T` : Commande node : ".$key."/".$nodes_list_to_process{$key}->{'command'}." \" >> /tmp/oar_hulot_LaunchedCommands ; sleep 30 ; echo \"`date +%T` : [FIN] Commande node : ".$key."/".$nodes_list_to_process{$key}->{'command'}." \" >> /tmp/oar_hulot_LaunchedCommands");
						push (@commandToLaunch, "HALT:$key");
						last; 
					};
					oar_error("[Hulot] Error during commands producing\n");
					exit 1;
				}
			}
			
			iolib::disconnect($base);
			
			oar_debug("[Hulot] Before send commands to windowForker (Window time is ".get_conf("ENERGY_SAVING_WINDOW_TIME").") : time = ".time."\n");
			if ($#commandToLaunch >= 0){
				# Make a fork in order to not block the pipe listening 
				
				$forker_pid = fork();
				if (defined($forker_pid)){
					if ($forker_pid == 0){
						#In the child
						oar_debug("Je suis le fils PID = $$ (".time().")\n");
						
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
					else{
						#In the parent
					}
				}else{
					oar_error("[Hulot] Fork system call failed\n");
				}
			}else{
				oar_debug("[Hulot] No new command to execute by the energy saving module\n");
			}
			
			# Check child endings
			while(($forker_pid = waitpid(-1, WNOHANG)) > 0) {
				register_wait_results($forker_pid, $?);
			}
			
			#oar_debug("[Hulot] After send commands to windowForker : time = ".time."\n");
			
			# Adds to running list last new launched commands
			add_to_hash(\%nodes_list_to_process, \%nodes_list_running);
			
			# Cleaning the list to process
			%nodes_list_to_process = ();
			
			#print "[DEBUG-HULOT] After cleaning nodes_list_to_process\n";
			#print "[DEBUG-HULOT] [APRES VIDAGE] nodes_list_to_process = ".Dumper(\%nodes_list_to_process)."\n";
			#print "[DEBUG-HULOT] [APRES VIDAGE] nodes_list_running = ".Dumper(\%nodes_list_running)."\n";
			
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
			oar_debug("[VERBOSE] Child process $pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n");
		}  
}


## wake_up_nodes
sub wake_up_nodes($) {
  my $nodes=shift;
  return send_cmd_to_fifo($nodes,"WAKEUP");
}

return(1);

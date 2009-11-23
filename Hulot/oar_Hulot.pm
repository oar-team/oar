package oar_Hulot;
require Exporter;
# This module is responsible of waking up / shutting down nodes
# when the scheduler decides it (writes it on a named pipe)

use strict;
use oar_conflib qw(init_conf get_conf is_conf);
use POSIX qw(strftime);
use Time::HiRes qw(gettimeofday);
use oar_iolib;
use oar_Tools;
use oar_Judas qw(oar_debug oar_warn oar_error send_log_by_email set_current_log_category);

require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(start_energy_loop);

my $FIFO="/tmp/oar_hulot_pipe";

# Log category
set_current_log_category('Hulot');

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

sub wake_up_nodes($) {
  my $nodes=shift;
  return send_cmd_to_fifo($nodes,"WAKEUP");
}

sub halt_nodes($) {
  my $nodes=shift;
  return send_cmd_to_fifo($nodes,"HALT");
}

sub start_energy_loop() {
    oar_debug("[DEBUG-HULOT] Starting start_energy_loop\n");
	
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

    # Open the fifo
    while(1){
       unless (open (FIFO, "$FIFO")) {
         oar_error("[Hulot] Could not open the fifo $FIFO!\n");
         exit(2);
       } 

    # Start to manage nodes comming on the fifo
       while (<FIFO>) {
          (my $cmd, my $nodes)=split(/:/,$_,2);
          my @nodes=split(/ /,$nodes);

          #TODO: SMART wake up / shutdown of the nodes
          # - Wake up by groups (50 nodes, sleep... 50 nodes, sleep...)
          # - Don't send the wake up command if it has already been sent for a given node
          # - Suspect node if wake up requested and not alive since ENERGY_SAVING_NODE_MANAGER_TIMEOUT
          # - Don't shut down nodes depending on ENERGY_SAVING_NODES_KEEPALIVE variable
          #
          # if ($cmd eq "HALT") {
          #    ...
          # }elsif ($cmd eq "WAKEUP") {
          #    ...
          # }
            print "[DEBUG-HULOT] Got $cmd for $nodes\n";
          #
       }
       close(FIFO);
    }
}

sub check_keepalive_nodes() {
  # TODO
  # function to be used by almighty, using ENERGY_SAVING_NODES_KEEPALIVE, select nodes to
  # wake up and send them to the pipe (wake_up_nodes($nodes))
  return 0;
}

return(1);

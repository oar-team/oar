package oar_Energy;
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

my $FIFO="/tmp/oar_energy_pipe";

# Log category
set_current_log_category('energy');

sub send_cmd_to_fifo($$) {
  my $nodes=shift;
  my $command=shift;
  my $nodes_list=join(' ',@$nodes);
  unless (open(FIFO, "> $FIFO")) {
    oar_error("[Energy] Could not open the fifo $FIFO!\n");
    return 1;
  }
  print FIFO "$command $nodes_list\n";
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

    # Creates the fifo if it doesn't exist
    unless (-p $FIFO) {
        unlink $FIFO;
        system('mknod', '-m','600',$FIFO,'p');
    }

    # Test if the FIFO has been correctly created
    unless (-p $FIFO) { 
        oar_error("[Energy] Could not create the fifo $FIFO!\n");
        exit(1);
    }

    # Open the fifo
    while(1){
       unless (open (FIFO, "$FIFO")) {
         oar_error("[Energy] Could not open the fifo $FIFO!\n");
         exit(2);
       } 

    # Start to manage nodes comming on the fifo
       while (<FIFO>) {
          #TODO HERE GOES THE CODE FOR NODES MANAGEMENT
            print "Got $_\n";
          #
       }
       close(FIFO);
    }
}

return(1);

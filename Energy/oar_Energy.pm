package oar_Energy;
require Exporter;
# This module is responsible of wkaing up / shutting down nodes
# when the scheduler decides it 

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

# Log category
set_current_log_category('energy');

sub start_energy_loop() {
    my $FIFO="/tmp/oar_energy_pipe";

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
       while (<FIFO>) {
          print "Got $_\n";
       }
       close(FIFO);
    }
}

return(1);

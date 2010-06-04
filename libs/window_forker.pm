package window_forker;
require Exporter;

use strict;
use warnings;
use POSIX ":sys_wait_h";
use oar_conflib qw(init_conf get_conf is_conf get_conf_with_default_param);
use oar_Judas qw(oar_debug oar_warn oar_error set_current_log_category);
use IPC::SysV qw(IPC_NOWAIT);
use Data::Dumper;
use oar_iolib;

# Log category
set_current_log_category('WindowForker');

# Declaration of the named pipe used by Hulot module
my $FIFO="/tmp/oar_hulot_pipe";

my $USE_TIME = 1;
unless (eval "use Time::HiRes qw(gettimeofday tv_interval);1"){
    $USE_TIME = 0;
}

my $DEFAULT_WINDOW_SIZE = 5;
my $DEFAULT_TIMEOUT = 30;

select STDOUT;
$| = 1;


# Treate finished processes
sub register_wait_results($$$$$$$){
    my ($pid,
        $return_code,
        $running_processes,
        $process_duration,
        $finished_processes,
        $nb_running_processes,
        $verbose) = @_;
    
    my $exit_value = $return_code >> 8;
    my $signal_num  = $return_code & 127;
    my $dumped_core = $return_code & 128;
    if ($pid > 0){
        if (defined($running_processes->{$pid})){
            $process_duration->{$running_processes->{$pid}}->{"end"} = [gettimeofday()] if ($USE_TIME == 1);
            warn("[VERBOSE] Child process $pid ended : exit_value = $exit_value, signal_num = $signal_num, dumped_core = $dumped_core \n") if ($verbose);
            $finished_processes->{$running_processes->{$pid}} = [$exit_value,$signal_num,$dumped_core];
            delete($running_processes->{$pid});
            $$nb_running_processes--;
        }
    }  
}


## launch
# Input parameters:
# - commands (ref on an array)
# - window size (scalar)
# - window time (scalar)
# - timeout (scalar)
# - verbose (0 or 1)
# - type of task (ref on a hash). Default is : %hash = ("type" => "default")

sub launch($$$$$$){
    my ($commands,
        $window_size,
        $window_time,
        $timeout,
        $verbose,
        $type) = @_;

    my $index = 0;
    my %running_processes;
    my $nb_running_processes = 0;
    my %finished_processes;
    my %process_duration;
    
    my $nextWindowTime = 0 ;
    my $nb_launching_processes_in_window = 0 ;
	
    # Check if there is at least one command to connect to
    if ($#{$commands} < 0){
        warn("/!\\ No command specified\n");
        return(\%finished_processes, \%process_duration);
    }

    # Check window size integrity
    if (!defined($window_size)){
        $window_size = $DEFAULT_WINDOW_SIZE;
    }elsif ($window_size < 1){
        warn("/!\\ Window size $window_size too small; minimum is 1!\n");
        return(\%finished_processes, \%process_duration);
    }

    # Check timeout
    if (!defined($timeout)){
        $timeout = $DEFAULT_TIMEOUT;
    }elsif ($timeout <= 0){
        warn("/!\\ Timeout cannot be negative; $timeout\n");
        return(\%finished_processes, \%process_duration);
    }
    
    # Check Window time (in seconds)
    if (!defined($window_time)){
        $window_time = 0;
    }elsif ($window_time < 0){
        warn("/!\\ Time between each window cannot be negative; $window_time.\nMinimum is 0 for no limit between each window");
        return(\%finished_processes, \%process_duration);
    }
    
    # Check window time integrity with timeout
    if ($window_time >= $timeout){
      warn("/!\\ Time between each window ($window_time sec) must be smaller than timeout ($timeout sec)");
      return(\%finished_processes, \%process_duration);
    }
    
    my %forker_type = %$type;
    # Check type
    if (keys(%forker_type)<=0){
      oar_error("[WindowForker] No type specified. Set to default type\n");
      %forker_type = ("type" => "default");
    }

    warn("[VERBOSE] Window size : $window_size\n") if ($verbose);
    warn("[VERBOSE] Timeout for each command : $timeout\n") if ($verbose);
    # Start to launch subprocesses with the window limitation
    my @timeout;
    my $pid;
    while (($index <= $#{$commands}) or ($#timeout >= 0)){
		warn("[VERBOSE] ".time." | $index / $#{$commands}\n") if ($verbose);
        # Check if window is full or not
        while((($nb_running_processes) < $window_size) and ($index <= $#{$commands})){
          
          # Check if previous window time is finished
          if((time() >= $nextWindowTime) and ($nb_launching_processes_in_window < $window_size)){
            warn("[VERBOSE] ".time." | fork process: $commands->[$index]\n") if ($verbose);
            $process_duration{$index}->{"start"} = [gettimeofday()] if ($USE_TIME == 1);
        
            $pid = fork();
            warn("[VERBOSE] ".time." | $pid pid = $pid\n") if ($verbose);
            if (defined($pid)){
                if ($pid == 0){
                    #In the child
                    warn("[VERBOSE] ".time." | $pid Execute command : $commands->[$index]\n") if ($verbose);
                    if($forker_type{"type"} eq "Hulot"){
                      # If Hulot request
                      my $command_to_exec="";
                      (my $cmd, my $node)=split(/:/,$commands->[$index],2);
                      my $base = iolib::connect()
                         or die("[Hulot] Cannot connect to the database\n");
                      if ($cmd eq "WAKEUP"){
                        $command_to_exec = "echo \"$node\" | ".get_conf("ENERGY_SAVING_NODE_MANAGER_WAKE_UP_CMD");
                        iolib::add_new_event_with_host($base,"WAKEUP_NODE",0,"Node $node wake-up request",[$node] );
                      }elsif ($cmd eq "HALT"){
                        $command_to_exec = "echo \"$node\" | ".get_conf("ENERGY_SAVING_NODE_MANAGER_SLEEP_CMD");
                        iolib::add_new_event_with_host($base,"HALT_NODE",0,"Node $node halt request",[$node] );
                      }
                      iolib::disconnect($base);
                      system($command_to_exec);
                      if (!msgsnd($forker_type{"id_msg"}, pack($forker_type{"template"}, 1, "$node:$cmd:".$?), IPC_NOWAIT)){
                        oar_error("[WindowForker] Failed to send message to Hulot by msgsnd(): $!\n");
                      }
                      exit 0;
                    }else{
                      exec($commands->[$index]);
                    }
                }
                else{
                  $running_processes{$pid} = $index;
                  $nb_running_processes++;
                  push(@timeout, [$pid,time()+$timeout]);
                  $nb_launching_processes_in_window++;
                  if ($nb_launching_processes_in_window >= $window_size){
                    # This window is full and we will be ready to start a new window once the current window will finish
                    warn("[DEBUG WINDFORKER] [".time."] [$pid] (NB launching = $nb_launching_processes_in_window) This window is full and we will be ready to start a new window once the current window will finish\n") if ($verbose);
                    $nb_launching_processes_in_window=0;
                    $nextWindowTime = time()+$window_time;
                    warn("[DEBUG WINDFORKER] [".time."] [$pid] (NB launching = $nb_launching_processes_in_window) Set new nextWindowTime at $nextWindowTime)\n") if ($verbose);
                  }
                }
            }else{
                warn("/!\\ fork system call failed for command:  $commands->[$index]\n");
            }
            $index++;
          }
        }
        # Check child endings
        warn("[VERBOSE] ".time." | $pid Check child endings\n") if ($verbose);
        while(($pid = waitpid(-1, WNOHANG)) > 0) {
            register_wait_results($pid, $?, \%running_processes, \%process_duration, \%finished_processes, \$nb_running_processes, $verbose);
        }

        # Check timeouts (at least every 0.1s)
        warn("[VERBOSE] ".time." | $pid Check timeouts\n") if ($verbose);
        my $t = 0;
        while(defined($timeout[$t]) and (($timeout[$t]->[1] < time()) or (!defined($running_processes{$timeout[$t]->[0]})))){
            if (!defined($running_processes{$timeout[$t]->[0]})){
               splice(@timeout,$t,1);
            }else{
                if ($timeout[$t]->[1] <= time()){
                    kill(9,$timeout[$t]->[0]);
                }
            }
            $t++;
        }
        select(undef,undef,undef,0.1) if ($t == 0);
    }
    
    
    ## Here, send "CHECK signal" to Hulot by the named pipe ?
    unless (open(FIFO, "> $FIFO")) {
      oar_error("[WindowForker] Could not open the fifo $FIFO!\n");
      return 1;
    }
    print FIFO "CHECK";
    close(FIFO);
    
    
    return(\%finished_processes, \%process_duration);
}

return 1;

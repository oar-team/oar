#!/usr/bin/env ruby 

require 'getoptlong'
require 'timeout'
require 'thread'
require 'monitor'

class Node
    attr_reader :name, :process_status, :process_pid, :process_startTime, :process_endTime, :process_ended
    attr_accessor :command_line, :stdin_pipe, :stdout_pipe, :stderr_pipe, :thread, :timeout

    def initialize(node_name)
        @name = node_name
        @process_ended = false
        @timeout = 0
    end

    def arm_timer
        if @timeout > 0
            return Thread.new{
                select(nil,nil,nil,@timeout)
                Process.kill("SIGALRM", @process_pid)
            }
        end
    end

    def start_process(pid)
        @process_startTime = Time.now.to_f
        @process_pid = pid
        @th_timer = arm_timer
    end
    
    def end_process(exit_code)
        @process_endTime = Time.now.to_f
        @th_timer.kill if @th_timer
        @process_ended = true
        @process_status = exit_code
    end

    def process_duration
        return(process_endTime - process_startTime)
    end
end

class Semaphore
   
    def initialize(initvalue = 1)
        @counter = initvalue
        @waiting_list = []
        @method_mutex = Mutex.new
    end

    def wait
        Thread.critical = true
        if (@counter -= 1) < 0
            @waiting_list.push(Thread.current)
            Thread.stop
        end
        self
    ensure
        Thread.critical = false
    end

    def signal
        Thread.critical = true
        begin
            if (@counter += 1) <= 0
                t = @waiting_list.shift
                t.wakeup if t
            end
        rescue ThreadError
        retry
        end
        self
    ensure
        Thread.critical = false
    end

    alias down wait
    alias up signal
    alias P wait
    alias V signal

    def exclusive
        wait
        yield
    ensure
        signal
    end

    alias synchronize exclusive
end

def launch_command(node,sema)
    sema.wait
    pw = IO::pipe   # pipe[0] for read, pipe[1] for write
    pr = IO::pipe
    pe = IO::pipe

    th = Thread.new {
        pid = fork {
            # CHILD
            pw[1].close
            STDIN.reopen(pw[0])
            pw[0].close

            pr[0].close
            STDOUT.reopen(pr[1])
            pr[1].close

            pe[0].close
            STDERR.reopen(pe[1])
            pe[1].close

            exec(node.command_line.to_s)
        }

        node.start_process(pid)
        Process.waitpid(pid)
        node.end_process($?)
        sema.signal
        
        #pw[1].close
        #pr[0].close
        #pe[0].close

        pw[0].close
        pr[1].close
        pe[1].close

    }

    
    node.stdin_pipe = pw[1]
    node.stdout_pipe = pr[0]
    node.stderr_pipe = pe[0]
    node.thread = th
end

# Return help message
def help_message
    str = <<EOS
Usage sentinelle.rb -h | [-m node] [-f node_file] [-c connector] [-w window_size] [-t timeout] [-p program] [-v]
    -h display this help message
    -m specify the node to contact (use several -m options for several nodes)
    -f give the name of a file which contains the node list (1 node per line)(use several -f options for several files)
    -c connector to use (default is ssh). If you want to change the user name, specify that in the connector (ex: -c "ssh -l user")
    -w window size (number of fork at the same time; default is 5)
    -t timeout for each command in second
    -p programm to run (default is "true")
    -v verbose mode

    The command returns for each node the tag BAD or GOOD with 3 numbers : exit code, signal number and core dump. If these 3 numbers are equal to 0 then the return tag is GOOD.

EOS
    return(str)
end


stdout_access = Mutex.new

nodes = []
program = "true"
window_size = 5
connector = "ssh"
timeout = 0
verbose = false
help = false
files = []

opts = GetoptLong.new(
    [ "--machine", "-m",    GetoptLong::REQUIRED_ARGUMENT ],
    [ "--program", "-p",    GetoptLong::REQUIRED_ARGUMENT ],
    [ "--connector", "-c",  GetoptLong::REQUIRED_ARGUMENT ],
    [ "--timeout", "-t",    GetoptLong::REQUIRED_ARGUMENT ],
    [ "--window", "-w",     GetoptLong::REQUIRED_ARGUMENT ],
    [ "--verbose", "-v",    GetoptLong::NO_ARGUMENT ],
    [ "--file", "-f",       GetoptLong::REQUIRED_ARGUMENT ],
    [ "--help", "-h",       GetoptLong::NO_ARGUMENT ]
)

opts.each do |option, value|
    if (option == "--machine")
        nodes.push(Node.new(value))
    elsif (option == "--program")
        program = value
    elsif (option == "--connector")
        connector = value
    elsif (option == "--timeout")
        timeout = value.to_f
    elsif (option == "--window")
        window_size = value.to_i
    elsif (option == "--verbose")
        verbose = true
    elsif (option == "--file")
        files.push(value)
    else
        help = true
    end
end

if help
    puts help_message
    exit(1)
end

# Extracte node names from files
files.each do |f|
    File.open(f, "r") do |fd|
        fd.each do |line|
            # Remove commentaries
            line = line.sub(/#.*$/,'')
            if line =~ /^\s*(\S+)\s*$/
                nodes.push(Node.new($1))
            end
        end
    end
end

# Check if there is at least one node to connect to
if nodes.length == 0 
    STDERR.puts "/!\\ No node specified (use -h option for more explanations)"
    exit(2)
end

window = nil
# Check window size integrity
if window_size < 1
    STDERR.puts "/!\\ Window size $window_size too small; minimum is 1!"
else
    window = Semaphore.new(window_size)
end

STDOUT.sync = true
STDERR.sync = true

time_start = Time.now.to_f
threads = []
nodes.each do |n|
    n.timeout = timeout
    n.command_line = connector + " " + n.name + " " + program
    launch_command(n,window)

    # Display stdout output
    threads.push(Thread.new {
#    begin
        n.stdout_pipe.each do |p|
                stdout_access.synchronize{
                    puts n.name + " (STDOUT)> " + p
                }
            end
            n.thread.join
            n.stdin_pipe.close
            n.stdout_pipe.close
#        rescue
#        end
        }
    )

    # Display stderr output
    threads.push(Thread.new {
#        begin
        n.stderr_pipe.each do |p|
                stdout_access.synchronize{
                    puts n.name + " (STDERR)> " + p
                }
            end
            n.thread.join
            n.stderr_pipe.close
#        rescue
#        end
        }
    )
                                                                                                
end

#STDIN.close

#nodes_tmp = nodes
#stdin_thread = Thread.new {
#    STDIN.each do |p|
#        nodes_tmp2 = []
#        nodes_tmp.each do |n|
#            if ! n.process_ended
#                n.stdin_pipe.puts p
#                nodes_tmp2.push(n)
#            end
#        end
#        if nodes_tmp2.length == 0
#            Thread.exit
#        else
#            nodes_tmp = nodes_tmp2
#        end
#    end
#}


threads.each do |t|
    t.join
end

time_stop = Time.now.to_f

#stdin_thread.terminate

# Display summary
puts 
nodes.each do |n|
    diagnostic = "BAD"
    diagnostic = "GOOD" if n.process_status.exitstatus.to_i == 0 and n.process_status.termsig.to_i == 0
    puts n.name + " : " + diagnostic + " (" +\
        n.process_status.exitstatus.to_i.to_s + "," +
        n.process_status.termsig.to_i.to_s + 
        ") " + sprintf("%.3f s", n.process_duration.to_f)
end
puts "Total duration : " + sprintf("%.3f s", time_stop - time_start) + " (" + nodes.length.to_s + " nodes)"

#!/usr/bin/ruby -w

###############
### loading ###
###############

# required for parsing config files
require 'yaml'

# required for making directories
require 'fileutils'

# required for opening bash session in the background
begin
 require 'session'
rescue LoadError => e
 warn "The \"session\" module is not found. You need to install it or load rubygems."
 warn "To install session as a rubygem: 'gem install session'."
 warn "Then, you may need to start ruby with -rubygems or to export RUBYOPT=rubygems"
 exit 1
end

# required by exec_shell() function
require 'tempfile'

# required for debugging
require 'pp'

############################
### function definitions ###
############################

### Hash that keeps elements in the insertion order -- it's more
### convenient for storing macrostep->microstep->comand structure
class OrderedHash < Hash
  def initialize
    @key_list = []
    super
  end
  def []=(key, value)
    if has_key?(key)
      super(key, value)
    else
      @key_list.push(key)
      super(key, value)
    end
  end

  def by_index(index)
    self[@key_list[index]]
  end

  def each
    @key_list.each do |key|
      yield( [key, self[key]] )
    end
  end

  def delete(key)
    @key_list = @key_list.delete_if { |x| x == key }
    super(key)
  end
end

### helper functions for output colorizing
def colorize(text, color_code)
  "#{color_code}#{text}\e[0m"
end

def red(text); colorize(text, "\e[31m\e[1m"); end
def green(text); colorize(text, "\e[32m\e[1m"); end
def blue(text); colorize(text, "\e[34m\e[1m"); end
def cyan(text); colorize(text, "\e[36m"); end

### function for converting command definitions into bash commands
def cmd_parse(cmd,step)
  if cmd.keys[0]=="check_cmd"
    return "which " + cmd.values[0] + " >/dev/null"
  elsif cmd.keys[0]=="check_cmd_chroot"
    return "chroot " + $chroot + " which " + cmd.values[0]
  elsif cmd.keys[0]=="exec_current"
    return "cd " + $bin_dir + "; " + cmd.values[0]
  elsif cmd.keys[0]=="exec_appliance"
    return "cd " + $chroot + "; " + cmd.values[0]
  elsif cmd.keys[0]=="exec_chroot"
    return "chroot " + $chroot + " " + cmd.values[0]
  elsif cmd.keys[0]=="append_file"
    return "echo \"" + cmd.values[0][1] + "\" >> " + $chroot + "/" + cmd.values[0][0]
  elsif cmd.keys[0]=="write_file"
    return "echo \"" + cmd.values[0][1] + "\" > " + $chroot + "/" + cmd.values[0][0]
  elsif cmd.keys[0]=="set_var"
    return "export " + cmd.values[0][0] + "=\"" + cmd.values[0][1] + "\""
  elsif cmd.keys[0]=="breakpoint"
    return "KML-breakpoint " + cmd.values[0]
  else
    printf("Step %s: no such command %s\n", step, cmd.keys[0])
    exit(9)
  end
end

def var_parse(str, path)
  str.gsub(/\$\$[a-zA-Z0-9\-_]*/) do
    |c|
    if $recipe['global'][c[2,c.length]]
      c=$recipe['global'][c[2,c.length]]
    else
      printf("%s: variable %s not found in [global] array\n", path, c)
      exit(6)
    end
    return $` + c + var_parse($', path)
  end
end

### prompt user in case of command execution error (non-zero exit code)
def error_prompt()
  answer = String.new
  $stdout.flush
  answer=$stdin.gets
  $log.stdin_write(answer)
  while (not ["r\n","c\n","a\n","s\n"].include?(answer)):
    print red("Press [r] to retry, [c] to continue with execution, [a] to abort execution, [s] to switch to shell: ")
    $stdout.flush
    answer=$stdin.gets
    $log.stdin_write(answer)
  end
  return answer[0,1]
end

### open prompt in the same enviromnent (shell) where the execution takes place
def start_shell(shell)
  puts green("Starting shell. Enter \\q to quit.")
  n = 0
  loop do
    print cyan("#{ n }:SHELL> ")
    command = $stdin.gets
    $log.stdin_write(command)
    #command = Readline.readline(cyan("#{ n }:SHELL> "), true) 
    if command =~ /^\s*\!*history\!*\s*$/
      open('shell.history','w'){|f| f.puts shell.history}
      next
    end
    #return if command =~ /^\s*(?:exit|quit)\s*$/io
    return if command =~ /^\s*\\q\s*$/io

    shell.execute(command, :stdout => $stdout, :stderr => $stderr)
    n += 1
  end
end

### print usage info
def usage()
  puts "Usage: kameleon.rb recipe.yaml"
end

######################################
### parsing command line arguments ###
######################################

if ARGV.length != 1
  usage()
  exit(1)
end

######################
### initialization ###
######################

# define global vars
$bin_dir=File.dirname($0)
version="1.0-beta"
required_globals = ["distrib", "workdir_base"]
required_commands = ["chroot", "which", "cat", "echo"]

# check UID (need to be root in order to chacge root)
if Process.uid != 0
  puts "Kameleon: need to be root!"
  exit(3)
end

# open bash session in the background
begin
  bash = Session::Bash.new()
rescue
  print "Failed to open bash session. ", $!, "\n"
  exit(3)
end

# load recipe
begin
  $recipe = YAML.load(File.open(ARGV[0]))
rescue
  print "Failed to open recipe file. ", $!, "\n"
  exit(2)
end

# check for required globals in the recipe file
required_globals.each do
  |var|
  if not $recipe['global'][var]:
    printf("Recipe misses required variable: %s \n", var)
    exit(4)
  end
end

### Create workdir and chroot directory.
# Dir structure should look like this:
# $workdir_base/<timestamp>/chroot
# Example: /var/tmp/kameleon/2009-07-10-18-55-34/chroot
# We also define two global vars here: $workdir and $chroot
$recipe['global']['workdir'] = $workdir = $recipe['global']['workdir_base']+"/"+Time.now.strftime("%Y-%m-%d-%H-%M-%S")
$recipe['global']['chroot'] = $chroot = $workdir + "/chroot"
$recipe['global']['bindir'] = $bin_dir
begin
  FileUtils.mkdir_p($chroot)
rescue
  print "Failed to create working direcroty. ", $!, "\n"
  exit(5)
end

# open logfile
class KLogger < File
  def initialize(filename)
    super(filename, 'w')
  end
  def open(filename)
    super(filename, 'w')
  end
  def write(str, stdout="yes")
    if stdout=="yes"
      STDOUT.write(str)
      STDOUT.flush()
    end
    super(str)
    flush()
  end
  def <<(str)
     write(str)
#    STDOUT.<<(str)
#    super(str)
  end
  def stdin_write(str)
     write(str,"no")
  end
end

$log=KLogger.new($workdir + ".log")
$stdout=$log
$stderr=$log
#Readline.output=log

###################
### Preparation ###
###################

# this hash will be used to store pieces of the bash script
script = OrderedHash.new()

# parse recipe, load macrostep files, load microsteps, convert command definitions
# into bash commands. All missing pieces should be detected and reported during
# this phase and before the actual system installation and image building (execution)
$recipe['steps'].each do
  |macrostep|

  # get the name of the step;
  # test if we're dealing with the list of microsteps
  if macrostep.kind_of?(String)
    step = macrostep
  else
    step = macrostep.keys[0]
  end

  # check for a file imported from another distrib
  if step =~ /(.+)\/(.+)/
    step=$2
    dist=$1
  else
    dist=""
  end

  # create a structure that looks something like this:
  # script["oar_init"]["start_appliance_mysql"][0] = \
  # = "chroot /path/to/chroot/dir /etc/init.d/mysql start"
  if script[step].nil?
    script[step] = OrderedHash.new()
  else
    puts "Error: '#{step}' defined twice! Exiting as the first occurence is going to"
    puts "not be executed at all and this is probably not what you want."
    exit(11)
  end

  # check for macrostep file (distro-specific or default)
  if dist != ""
    if File.file?(path0 = $bin_dir + "/steps/" + dist + "/" + step + ".yaml")
      path=path0
    else
      printf("%s: macrostep file is missing: \n * %s\n", step, path0)
      exit(6)
    end
  else
    if File.file?(path1 = $bin_dir + "/steps/" + $recipe['global']['distrib'] + "/" + step + ".yaml")
      path=path1
    elsif File.file?(path2 = $bin_dir + "/steps/default/" + step + ".yaml")
      path=path2
    else
      printf("%s: macrostep file is missing: \n * %s\n * %s\n", step, path1, path2)
      exit(6)
    end
  end

  # load macrostep file
  begin
    macrostep_yaml = YAML.load(File.open(path))
  rescue
    print "Failed to open macrostep file. ", $!, "\n"
    exit(7)
  end

  macrostep_yaml[step].each_index do
    |key|
    microstep=macrostep_yaml[step][key]
    if microstep.keys[0] == "include"
      # load macrostep file
      begin
        macrostep_include_yaml = YAML.load(File.open($bin_dir + "/steps/" + microstep.values[0]))
      rescue
        print "Failed to open macrostep file. ", $!, "\n"
        exit(7)
      end
      ind = 1
      macrostep_include_yaml.each do
        |microstep_include|
        macrostep_yaml[step].insert(key+ind, microstep_include)
        ind+=1
      end
      macrostep_yaml[step].delete_at(key)
    end
  end

  # traverse macrosteps->microsteps->commands structure, parse commands;
  # test if we're dealing with the list of microsteps
  if macrostep.kind_of?(String)
    macrostep_yaml[step].each do
      |microstep|
      script[step][microstep.keys[0]] = Array.new()
      microstep.values[0].each do
        |command|
        script[step][microstep.keys[0]].push(var_parse(cmd_parse(command,step+"->"+microstep.keys[0]), path))
      end
    end
  else
    if macrostep.values[0].nil?
      puts "Error in recipe: '#{step}' microsteps list is empty!"
      exit 1
    end
    macrostep.values[0].each do
      |microstep|
      script[step][microstep] = Array.new()

      found = nil
      counter = 0
      macrostep_yaml[step].each do
        |microstep_yaml|
        if microstep_yaml.keys[0] == microstep
          found=counter
        end
        counter+=1
      end

      if not found
        printf("Microstep %s required by %s missing in %s.\n", microstep, ARGV[0], path)
        exit(8)
      end

      macrostep_yaml[step][found].values[0].each do
        |command|
        script[step][microstep].push(var_parse(cmd_parse(command,step+"->"+microstep), path))
      end

    end
  end
end

#################
### Execution ###
#################

puts blue("\n ### ") + green("Welcome to Kameleon " + version) + blue(" ###\n")

# traverse macrostep->microstep->command structure
script.each do
  |macrostep|
  macrostep_name=macrostep[0]
  macrostep[1].each do
    |microstep|
    microstep_name=microstep[0]
    puts cyan("->") + green("| Executing " + macrostep_name) + cyan("->") + green(microstep_name)
    microstep[1].each do
      |command|
      begin
        next_cmd=0
        while next_cmd!=1:
          # check for special command "KML-breakpoint"
          if command[0,14] == "KML-breakpoint"
            puts green("  |-> Breakpoint: " + command[15,command.length])
            # open interactive shell instead of executing a command
            start_shell(bash)
          else
            puts green("  |-> " + command)
            # execute the command in the background bash session, connecting
            # it's stdout and stderr to kameleon's stdout and stderr
            bash.execute(command, :stdout => $stdout, :stderr => $stderr)
          end
          # check exit status, and stop execution on non-zero exit code
          if (bash.exit_status !=0) && (command[0,14] != "KML-breakpoint")
            answer=String.new
            puts red("Error executing command.")
            print red("Press [r] to retry, [c] to continue with execution, [a] to abort execution, [s] to switch to shell: ")
            # offer three options: continue, abort, switch to shell (manually fix the error and then continue)
            while not ["c","r"].include?(answer=error_prompt):
              if answer=="s"
                start_shell(bash)
                puts green("Getting back to Kameleon ...")
                print green("Press [r] to retry, [c] to continue with execution, [a] to abort execution, [s] to switch to shell: ")
              elsif answer=="a"
                puts red("Aborting execution ...")
                puts red("You should clean workdir: " + $workdir)
                system("umount " + $workdir + "/chroot/proc 2>/dev/null")
                exit(10)
              end
            end
            if answer=="c"
              next_cmd=1
            end
          else
            next_cmd=1
          end
        end
      rescue
        printf "%s->%s: Failed to execute command: %s\nException: ", macrostep_name, microstep_name, command
        print $!, "\n"
        exit(3)
      end
    end
  end
end

#!/usr/bin/ruby -w
#    Kameleon: a tool to build virtual machines or livecd images
#    Copyright (C) 2009-2010 LIG <http://lig.imag.fr/>
#
#    This program is free software; you can redistribute it and/or modify
#    it under the terms of the GNU General Public License as published by
#    the Free Software Foundation; either version 2 of the License, or
#    (at your option) any later version.
#
#    This program is distributed in the hope that it will be useful,
#    but WITHOUT ANY WARRANTY; without even the implied warranty of
#    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#    GNU General Public License for more details.
#
#    You should have received a copy of the GNU General Public License
#    along with this program; if not, write to the Free Software
#    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

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
 warn "The \"session\" module is not found. You need to install it."
 warn "To install session as a rubygem, type 'gem install session'."
 begin
   Gem.ruby_version
 rescue
   warn "\nFurthermore, Rubygems does not seems to be loaded."
   warn "You maybe have to enable rubygems, by setting RUBYOPT=rubygems"
   warn "or starting ruby with the -rubygems option."
   exit 1
 end
 exit 1
end

# required by exec_shell() function
require 'tempfile'

# required for debugging
require 'pp'

# History file
$histfile="#{ENV['HOME']}/.kameleon_history"
$history=[]

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
    return "cd " + $cur_dir + "; " + cmd.values[0]
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

### save an history file
def save_history
  open($histfile,'a') do |f|
    $history.each { |h| f.puts h }
  end
  $history = []
end

### open prompt in the same enviromnent (shell) where the execution takes place
def start_shell(shell,histfile)
  puts green("Starting shell. Enter 'exit' to return to kameleon.")
#  n = 0
  unless File.file?(rcfile="#{ENV['HOME']}/.kameleon_rc")
    open(rcfile,'w') do |f| 
      f.puts "source #{$recipe['global']['workdir_base']}/\$KAMELEON_TIMESTAMP/kameleon_env" 
      f.puts "PS1='\\e[36;1mKAMELEON \\w # \\e[0m'" 
    end
  end
  shell.execute("env |egrep -v '^PWD=|^LS_COLORS=|^ZLSCOLORS='> #{$workdir}/kameleon_env")
  system("cd #{$workdir}; KAMELEON_TIMESTAMP=#{$timestamp} HISTFILE='#{histfile}' bash --rcfile #{rcfile}")
 
 # loop do
 #   print cyan("#{ n }:SHELL> ")
 #   command = $stdin.gets
 #   $log.stdin_"write(command)
 #   #command = Readline.readline(cyan("#{ n }:SHELL> "), true) 
 #   if command =~ /^\s*\!*history\!*\s*$/
 #     open('shell.history','w'){|f| f.puts shell.history}
 #     next
 #   end
 #   #return if command =~ /^\s*(?:exit|quit)\s*$/io
 #   return if command =~ /^\s*\\q\s*$/io
 #
 #   shell.execute(command, :stdout => $stdout, :stderr => $stderr)
 #   n += 1
 # end
end

### Cleaning function
def clean()
  puts red("Running cleaning script...")
  system("bash " + $chroot + "/clean.sh")
  system("umount " + $workdir + "/chroot/proc 2>/dev/null")
  system("umount " + $workdir + "/mnt/proc 2>/dev/null")
end 

### print usage info
def usage()
  puts "Usage: kameleon.rb recipe[.yaml]"
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
$cur_dir=Dir.pwd
$var_dir="/var/lib/kameleon"
$kameleon_dir=File.dirname($0)
version="1.1b"
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
path=""
searched_pathes=""
[$cur_dir,$var_dir,$kameleon_dir].each do |dir|
  if File.file?(search_path1 = dir + "/recipes/" + ARGV[0])
    path=search_path1
    break
  elsif File.file?(search_path2 = dir + "/recipes/" + ARGV[0] + ".yaml")
    path=search_path2
    break
  else
    searched_pathes=searched_pathes + " * " + search_path1 + "\n * " + search_path2 + "\n"
  end
end
if path == ""
  printf("%s: could not find recipe in none of the following files: \n%s", ARGV[0], searched_pathes)
  exit(2)
end
begin
  puts cyan("->") + green("| Loading " + path)
  $recipe = YAML.load(File.open(path))
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
$timestamp=Time.now.strftime("%Y-%m-%d-%H-%M-%S")
$recipe['global']['workdir'] = $workdir = $recipe['global']['workdir_base']+"/"+$timestamp
$recipe['global']['chroot'] = $chroot = $workdir + "/chroot"
$recipe['global']['bindir'] = $cur_dir
begin
  FileUtils.mkdir_p($chroot)
rescue
  print "Failed to create working directory. ", $!, "\n"
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
  path=""
  searched_pathes=""
  if dist != ""
    [$cur_dir,$var_dir,$kameleon_dir].each do |dir|
      if File.file?(search_path = dir + "/steps/" + dist + "/" + step + ".yaml")
        path=search_path
        break
      else
        searched_pathes=searched_pathes + " * " + search_path + "\n"
      end
    end
  else
    [$cur_dir,$var_dir,$kameleon_dir].each do |dir|
      if File.file?(search_path1 = dir + "/steps/" + $recipe['global']['distrib'] + "/" + step + ".yaml")
        path=search_path1
        break
      elsif File.file?(search_path2 = dir + "/steps/default/" + step + ".yaml")
        path=search_path2
        break
      else
        searched_pathes=searched_pathes + " * " + search_path1 + "\n * " + search_path2 + "\n"
      end
    end
  end
  if path == ""
    printf("%s: macrostep file is missing: \n%s", step, searched_pathes)
    exit(6)
  end

  # load macrostep file
  begin
    puts green("  | Loading " + path)
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
        macrostep_include_yaml = YAML.load(File.open($cur_dir + "/steps/" + microstep.values[0]))
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

system("touch " + $chroot + "/clean.sh")

trap("INT") {
  puts red("Interrupted.")
  clean()
  puts("Exiting kameleon.")
  save_history
  exit
}

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
            save_history
            start_shell(bash,$histfile)
          else
            puts green("  |-> " + command)
            # execute the command in the background bash session, connecting
            # it's stdout and stderr to kameleon's stdout and stderr
            bash.execute(command, :stdout => $stdout, :stderr => $stderr)
            $history << command
          end
          # check exit status, and stop execution on non-zero exit code
          if (bash.exit_status !=0) && (command[0,14] != "KML-breakpoint")
            answer=String.new
            puts red("Error executing command.")
            print red("Press [r] to retry, [c] to continue with execution, [a] to abort execution, [s] to switch to shell: ")
            # offer three options: continue, abort, switch to shell (manually fix the error and then continue)
            while not ["c","r"].include?(answer=error_prompt):
              if answer=="s"
                save_history 
                start_shell(bash,$histfile)
                puts green("Getting back to Kameleon ...")
                print green("Press [r] to retry, [c] to continue with execution, [a] to abort execution, [s] to switch to shell: ")
              elsif answer=="a"
                puts red("Aborting execution ...")
                clean()
                puts red("You should clean workdir: " + $workdir)
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
save_history

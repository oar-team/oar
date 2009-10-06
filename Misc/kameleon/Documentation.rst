========================
 Kameleon documentation
========================

.. section-numbering::
.. contents:: Table of Contents

-------------------------------------------------------------------------------

Introduction
============

Kameleon is a simple but powerfull tool to generate customized appliances. 
But as it is designed to be very generic you can probably do a lot more 
than that.

Presentation
============

Kameleon is a ruby script that parses YAML files containing a set of *Macrosteps* and *Microsteps*.
These YAML files are either *recipes* or *Macrosteps*.
A *recipe* is a set of global variables declaration and a set of steps: the *Macrosteps* which are stored in the *steps* directory.
A *Macrostep* is a set of *Microsteps* and a *Microstep* is a set of YAML nodes containing a special Kameleon
command and its options.

A Microstep will look like: 

microstep_name:

  \- Kameleon_cmd1:       something_to_do_with_this_command1

  \- Kameleon_cmd2:       something_to_do_with_this_command2

  \- ...
 

A Macrostep will look like:

macrostep_name:

  \- microstep1:

    \- Kameleon_cmd1:       something_to_do_with_this_command1

    \- Kameleon_cmd2:       something_to_do_with_this_command2

  \- microstep2:

    \- Kameleon_cmd1:       something_to_do_with_this_command1


Kameleon commands
=================

Each kameleon command does a particular shell command.
Kameleon commands are: 

  - include:			yaml_file_to_include		=> allows to include another macrostep yaml file
  - breakpoint:			text_to_display			=> do a breakpoint during the execution of kameleon
  - check_cmd:			cmd_to_check_if_available	=> execute "which cmd_to_check_if_available"
  - check_cmd_chroot:		cmd_to_check_if_available	=> execute "which cmd_to_check_if_available" chrooted in the appliance
  - exec_current:		cmd				=> execute cmd in the current directory
  - exec_appliance:		cmd				=> execute cmd in the appliance directory
  - exec_chroot:		cmd				=> execute cmd chrooted in the appliance
  - append_file:						=> append line to the file

     - file_path
     - \|

       line_to_append
  - write_file:							=> write lines to the file

     - file_path
     - \|

       lines_to_write
  - set_var:							=> do an export variable="value"

     - variable
     - \|

       value


How-to and Tips
===============

Create a recipe
---------------

You can 




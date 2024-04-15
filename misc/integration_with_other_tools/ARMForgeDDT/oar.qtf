#!/bin/bash

# Name: OAR
#
# WARNING: If you install a new version of Arm Forge to the same
#          directory as this installation, then this file will be overwritten.
#          If you customize this script at all, please rename it.
#
# N.B. These values are read and used in the ARM Forge DDT GUI 
#      when a user selects this template:
# 
# submit: oarsub -S -t allow_classic_ssh -p "cluster='paravance'"
# display: oarstat -u <username>
# job regexp: OAR_JOB_ID=(\d+) 
# cancel: oardel JOB_ID_TAG
# 
# N.B. Set the queue to use (use 'default' for the default) in the "Edit Queue Paramaters..." GUI in Job Submission Settings
#      
# WALL_CLOCK_LIMIT_TAG: {type=text,label="Wall Clock Limit",default="00:30:00",mask="09:09:09"}
# QUEUE_TAG: {type=text,label="Queue",default=default}

## Arm Forge will generate a submission script by
## replacing these tags:
##        TAG NAME         |         DESCRIPTION           |        EXAMPLE
## ---------------------------------------------------------------------------
## PROGRAM_TAG             | target path and filename      | /users/ned/a.out
## PROGRAM_ARGUMENTS_TAG   | arguments to target program   | -myarg myval
## NUM_PROCS_TAG           | total number of processes     | 16
## NUM_NODES_TAG           | number of compute nodes       | 8
## PROCS_PER_NODE_TAG      | processes per node            | 2
## NUM_THREADS_TAG         | OpenMP threads per process    | 4
## DDT_DEBUGGER_ARGUMENTS_TAG | arguments to be passed to forge-backend
## MPIRUN_TAG              | name of mpirun executable     | mpirun
## AUTO_MPI_ARGUMENTS_TAG  | mpirun arguments              | -np 4
## EXTRA_MPI_ARGUMENTS_TAG | extra mpirun arguments        | -x FAST=1

 
### /core=PROCS_PER_NODE_TAG,  <---- if we want to use exact numbers of cores (not just whole nodes) then use --mca plm_rsh_agent "oarsh" in EXTRA_MPI_ARGUMENTS_TAG populated from DDT GUI
### To use whole nodes we can then use : -t allow_classic_ssh on oarsub command line in GUI

#OAR -q QUEUE_TAG
#OAR -l nodes=NUM_NODES_TAG,walltime=WALL_CLOCK_LIMIT_TAG 
#OAR -O PROGRAM_TAG-%jobid%-allinea.stdout
#OAR -E PROGRAM_TAG-%jobid%-allinea.stderr

## Use these to see what DDT is substituting in the template
# echo "auto_launch_tag        : AUTO_LAUNCH_TAG"
# echo "ddt_debugger_arguments : DDT_DEBUGGER_ARGUMENTS_TAG"
# echo "mpirun_tag             : MPIRUN_TAG"
# echo "auto_mpi_arguments_tag : AUTO_MPI_ARGUMENTS_TAG"
# echo "extra_mpi_arguments_tag: EXTRA_MPI_ARGUMENTS_TAG"
# echo "debug_starter_tag      : DEBUG_STARTER_TAG"
# echo "ddt_client_tag         : DDT_CLIENT_TAG"
# echo "program_tag            : PROGRAM_TAG" 
# echo "progam_arguments_tag   : PROGRAM_ARGUMENTS_TAG"
# echo "num_procs_tag          : NUM_PROCS_TAG"
# echo "OAR_NODE_FILE          : $OAR_NODE_FILE"
# cat $OAR_NODE_FILE

## The following line will use exactly the same default settings that
## Arm Forge uses to launch without the queue.

# AUTO_LAUNCH_TAG

# https://developer.arm.com/products/software-development-tools/hpc/get-support

## Add these to the "mpirun arguments" in the DDT GUI as needed:
# For Infiniband clusters on Grid5000 use   : --mca btl openib,self --mca pml ^cm
# To disable infiniband and omnipath        : --mca btl self,tcp --mca mtl ^psm2,ofi 
# To force normal ethernet                  : --mca btl_tcp_if_exclude ib0,lo 

## If you need to install a package on each node (from: https://unix.stackexchange.com/questions/19008/automatically-run-commands-over-ssh-on-many-servers)
## Reminder: this requires requesting whole nodes.
# cat $OAR_NODEFILE | uniq > mynodes.tmp
# count=0
# while IFS= read -r userhost; do
    # oarsh -n -o BatchMode=yes ${userhost} 'sudo-g5k apt-get -y install libtbb-dev' 
    # count=`expr $count + 1`
# done < mynodes.tmp

## N.B. The path to Arm Forge is set in .bashrc file, which also loads Spack libraries and modules
forge-mpirun EXTRA_MPI_ARGUMENTS_TAG  -machinefile $OAR_NODEFILE AUTO_MPI_ARGUMENTS_TAG  --  PROGRAM_TAG PROGRAM_ARGUMENTS_TAG
  

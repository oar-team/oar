#!/bin/bash
set -e

# This script takes the ip of a node as an argument and check
# the core affinity with physical cpus to update the oar cpuset
# property corresponding to this node.
# This script is intented to be inserted into the oarnodesetting_ssh
# script that makes a node alive at boot time.
 
OARNODESETTINGCMD=/usr/sbin/oarnodesetting
OARNODESCMD=/usr/bin/oarnodes

if [ $# != 1 ]
then
  echo "usage: $0 <node_ip>"
  exit 1
fi

CORE_MATHING=`ssh -p 6667 $1 cat /proc/cpuinfo |awk -F"\t*: *" '{if ($1 == "processor") proc=$2; if ($1 == "physical id") phys=$2; if ($1 == "core id") print phys ":" $2 ":" proc}'|sort`

CURRENT_CORES=`$OARNODESCMD -Y --sql "ip='$1'"|awk -F" *: *" '{if (match($1," +core$")) core=$2; if (match($1," +cpu$")) print $2 ":" core}'|sort`

if [ "`echo $CURRENT_CORES |wc -w`" != "`echo $CORE_MATHING |wc -w`" ]
then
  echo "ERROR: Number of cores on the node mismatch with the number of cores into OAR!"
  exit 2
fi

declare -i c=0
for i in $CORE_MATHING
do
  let c=c+1
  CORE_ID=`echo $CURRENT_CORES |cut -d" " -f$c|cut -d: -f2`
  PROC_ID=`echo $i|cut -d":" -f3`
  $OARNODESETTINGCMD -p "cpuset=$PROC_ID" --sql "core=$CORE_ID"
done

#!/bin/sh
# $Id$
# Detect resources on the node and print corresponding OAR commands

CPUS=$(cat /proc/cpuinfo  | grep ^processor | awk '{print $3}')
MEM=$(cat /proc/meminfo | grep ^MemTotal | awk '{print $2}')

HOST=$(hostname)

((MEM = $MEM / 1024))

for i in $CPUS
do
    echo "oarnodesetting -a -h $HOST -p cpuset=$i -p mem=$MEM"
done

#!/bin/bash
#
# Script to evaluate the end to end launching time of only one job
# It's use
#  date +%s > now; oarsub -l resource_id=1 times_script
#
t0=$(cat now)
t1=$(date +%s)
tl=$(($t1-$t0))
date
echo Nb resources: $(wc -l $OAR_NODEFILE)
echo Launching time: $tl sec. 
echo $tl

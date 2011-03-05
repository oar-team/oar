#!/bin/bash
BKM_SYNC_HOST=$1
BKM_SYNC_PORT=$2
OAR_JOB_ID=$3
OAR_MOLDABLE_JOB_ID=$4
WALLTIME=$5

echo "BKM-pilot args:" $@
echo "BKM-pilot SLURM_NODELIST: " $SLURM_NODELIST 

#TODO switch case depending of foreign rjms
NODE_FILE= 
NODE_LIST=$SLURM_NODELIST 

#
# notify black-maria-sync daemon
#
BKM_SYNC_DATA="{j_id=$OAR_JOB_ID, moldable_j_id=$OAR_MOLDABLE_JOB_ID, node_file='$NODE_FILE', node_list='NODE_LIST'}"
echo $BKM_SYNC_DATA
echo $BKM_SYNC_DATA | nc $BKM_SYNC_HOST $BKM_SYNC_PORT

# time to sleep
#sleep $WALLTIME
sleep 2

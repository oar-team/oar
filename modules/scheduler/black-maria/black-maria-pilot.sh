#!/bin/bash

BKM_SYNC_HOST=$1
BKM_SYNC_PORT=$2
OAR_JOB_ID=$3
OAR_MOLDABLE_JOB_ID=$4
WALLTIME=$5

SLURM_NODELIST="slurm_nodelist.txt"

#TODO switch case depending of foreign jrms
NODE_FILE=$SLURM_NODELIST 

#
# notify black-maria-sync daemon
#
BKM_SYNC_DATA="{['j_id']=$OAR_JOB_ID, ['moldable_j_id']=$OAR_MOLDABLE_JOB_ID, ['nodes_file']='$NODE_FILE'}"
echo $BKM_SYNC_DATA
echo $BKM_SYNC_DATA | nc $BKM_SYNC_HOST $BKM_SYN_PORT

# time to sleep
sleep $WALLTIME


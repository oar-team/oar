#!/bin/bash
set -e

kadeploy3 -f $OAR_FILE_NODES -e debian-lustre -k
MDS=`cat $OAR_FILE_NODES|sort -u|head -1`
cat $OAR_FILE_NODES |sort -u|tail -n +2|head -n -1 > OSS_FILE
CLIENT=`cat $OAR_FILE_NODES|sort -u|tail -1`
ssh root@$MDS lustre_mds_init
sleep 3
taktuk -s -c "ssh -l root" -f OSS_FILE  b e [ lustre_oss_init $MDS ]
ssh root@$CLIENT "lustre_client_init $MDS"
sleep 3
ssh root@$CLIENT "iozone -l 1 -u 3 -R -r 1024k -s 10m -F /mnt/lustre/test1 /mnt/lustre/test2 /mnt/lustre/test3"

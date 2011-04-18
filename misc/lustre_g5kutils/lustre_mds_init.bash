#!/bin/bash
set -e

TMP_PART=`df /tmp|tail -1|awk '{print $1}'`
umount $TMP_PART
pvcreate $TMP_PART
vgcreate vg00 $TMP_PART
lvcreate --name vg00/mdt --size 1G
mkfs.lustre --fsname lustre --mdt --mgs /dev/vg00/mdt
mkdir /mdt
mount -t lustre /dev/vg00/mdt /mdt

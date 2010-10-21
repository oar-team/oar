#!/bin/bash
set -e

if [ "$1" = "" ]
then
  echo "usage: $0 <mgsnode>"
  exit 1
fi

TMP_PART=`df /tmp|tail -1|awk '{print $1}'`
umount $TMP_PART
pvcreate $TMP_PART
vgcreate vg00 $TMP_PART
lvcreate --name vg00/ost --size 10G
mkfs.lustre --fsname lustre --ost --mgsnode=$1@tcp0 /dev/vg00/ost
mkdir /mnt/ost
mount -t lustre /dev/vg00/ost /mnt/ost

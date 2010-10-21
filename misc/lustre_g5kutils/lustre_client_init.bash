#!/bin/bash
set -e

if [ "$1" = "" ]
then
  echo "usage: $0 <mgsnode>"
  exit 1
fi

modprobe lustre
mkdir -p /mnt/lustre
mount -t lustre $1@tcp0:/lustre /mnt/lustre


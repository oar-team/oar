#!/bin/bash
CGROOT=${1:-/dev/cpuset/oar}
while true; do
  clear
  if [ -d $CGROOT ]; then
    find $CGROOT \( -name cpuset.cpus -o -name tasks -o -name cpuset.mems \) -exec grep -H "" {} \;
  else
    echo "no $CGROOT"
  fi
  sleep 1
done

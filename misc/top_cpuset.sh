#!/bin/bash
while true; do
  clear
  if [ -d /dev/cpuset/oar ]; then
    find /dev/cpuset/oar \( -name cpuset.cpus -o -name tasks \) -exec grep -H "" {} \;
  else
    echo "/dev/cpuset/oar not created yet..."
  fi
  sleep 1
done

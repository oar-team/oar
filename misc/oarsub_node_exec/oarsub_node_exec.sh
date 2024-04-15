#!/bin/bash -x
set -e
echo "script: $0 $@ <- $$"
ps faux
if [ "$HOSTNAME" == "frontend" ]; then
  mkdir -p /sys/fs/cgroup/cpuset/oardocker/frontend
  cat /sys/fs/cgroup/cpuset/oardocker/cpuset.cpus > /sys/fs/cgroup/cpuset/oardocker/frontend/cpuset.cpus
  cat /sys/fs/cgroup/cpuset/oardocker/cpuset.mems > /sys/fs/cgroup/cpuset/oardocker/frontend/cpuset.mems
  PIDS=${1%%:*}
  for pid in ${PIDS//,/  }; do
    echo $pid > /sys/fs/cgroup/cpuset/oardocker/frontend/tasks
  done
else
  echo "Do nothing"
fi

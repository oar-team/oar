#!/bin/bash -x
ps --forest -ed -o pid,uid,cmd,cgroup 
cat /proc/seft/cgroup
cat /sys/fs/cgroup/cpuset$(< /proc/self/cpuset)/tasks

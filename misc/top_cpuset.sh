#!/bin/bash

CGROOT="/sys/fs/cgroup/cpuset/oardocker/"
KILL=
WIPE=

usage() {
	cat <<EOF
Usage:
  ${0##*/} [-d <cpuset dir>] [-k] [-W] [-h]
Options:
  -d <dir>  set the cgroup cpuset base directory
  -k        kill existing processes and clear job cpuset directories
  -W        wipe out oardocker cpuset directories
  -h        print this message

EOF
}

while getopts "kWd:h" opt; do
	case $opt in
		k)
			KILL=1
		;;
    W)
      WIPE=1
    ;;
	  d)
			CGROOT=$OPTARG
		;;
		h)
			usage
			exit 0
		;;
		*)
			usage 1>&2
			exit 1
		;;
	esac
done

kill_tasks() {
  echo "# Kill tasks:"
  find $CGROOT -name tasks -exec grep -H -o "[[:digit:]]\+" {} \;
  echo "# Remove directories:"
	if [ -n "WIPE" ]; then
    find $CGROOT -depth -type d
  else
    find $CGROOT -depth -type d -name "oar.*"
  fi
  ANSWER=
  read -s -n 1 -p "<Press y to confirm, or any key to cancel>" ANSWER
  echo
  if [ "$ANSWER" == "y" ]; then
    find $CGROOT -name tasks -exec cat {} \; | sudo xargs -n 1 kill -9
	  if [ -n "WIPE" ]; then
    	find $CGROOT -depth -type d -exec sudo rmdir {} \;
    else
    	find $CGROOT -depth -type d -name "oar.*" -exec sudo rmdir {} \;
    fi
  fi
}

if [ -n "$WIPE" ]; then
	kill_tasks
  exit
fi

if [ -n "$KILL" ]; then 
  kill_tasks
  exit
fi

while true; do
  clear
  if [ -d $CGROOT ]; then
    find $CGROOT \( -name cpuset.cpus -o -name tasks -o -name cpuset.mems \) -exec grep -H "" {} \;
  else
    echo "no $CGROOT"
  fi
  ANSWER=""
  read -s -t 1 -n 1 -p "<Press any key to refresh, 'k' to kill or 'q' to quit>" ANSWER
  case $ANSWER in 
    k)
    echo
    echo
    kill_tasks
    ;;
    q)
    echo
    exit 0
    ;;
  esac
done

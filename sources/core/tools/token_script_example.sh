#!/bin/sh                                                                                                                                                                 
# You can use this script to define constraints upon a token licence server.
# See oar.conf (SCHEDULER_TOKEN_SCRIPTS)
#
# $1: license servers
# $2: license name
# $3: Pattern to match


#PATTERN='^Users of VP_SOLVER'
LMUTIL=/opt/intel/lmutil

LINE=$($LMUTIL lmstat -c "$1" -f "$2" | grep "$3")
#echo $LINE

TOTAL=$(echo $LINE | awk -F " " '{print $6}')
USED=$(echo $LINE | awk -F " " '{print $11}')

#echo $TOTAL
#echo $USED

((FREE = $TOTAL - $USED))

echo $FREE


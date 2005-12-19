#!/bin/sh
# launch user shell with OAR variables
# $1 --> file name where to find reservation node names
# $2 --> number of nodes
# $3 --> ID job
# $4 --> user
# $5 --> shell
# $6 --> launchingDirectory
# $7 --> I if it is an interactive submission else N
# $8 --> command name
# $9 --> command to launch with arguments


if [ "a$TERM" == "a" ] || [ "$TERM" == "unknown" ]
then
    export TERM=xterm
fi

export OAR_FILE_NODES=$1
export OAR_NB_NODES=$2
export OAR_JOBID=$3
export OAR_USER=$4
export OAR_WORKDIR=$6

export OAR_NODEFILE=$OAR_FILE_NODES
export OAR_NODENUM=$OAR_NB_NODES
export OAR_NODECOUNT=$OAR_NODENUM
export OAR_O_WORKDIR=$6

#go to working directory
#( cd $6 >& /dev/null ) && cd $6
if ( cd $6 &> /dev/null )
then
    cd $6
else
    #Can not go into working directory
    exit 1
fi

if [ "$7" == "I" ]
then
    $5
elif [ "$7" == "N" ]
then
    OUT_FILE="OAR.$8.$OAR_JOBID.stdout"
    ERR_FILE="OAR.$8.$OAR_JOBID.stderr"

    #Test if we can write into stout and stderr files
    if ! ( > $OUT_FILE ) &> /dev/null || ! ( > $ERR_FILE ) &> /dev/null
    then
        exit 2
    fi
    shift 8
#    ($@ > OAR.$COMMAND_NAME.$OAR_JOBID.stdout) >& OAR.$COMMAND_NAME.$OAR_JOBID.stderr
    ($@ > $OUT_FILE) >& $ERR_FILE
fi

exit 0

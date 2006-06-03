#!/bin/sh
# launch user shell with OAR variables
# $1 --> file name where to find reservation node names
# $2 --> ID job
# $3 --> user
# $4 --> shell
# $5 --> launchingDirectory
# $6 --> I if it is an interactive submission else P
# $7 --> stdout file name
# $8 --> stderr file name
# $9 --> file name where to store my PID for oarexec
# $10 --> command to launch with arguments


if [ "a$TERM" == "a" ] || [ "$TERM" == "unknown" ]
then
    export TERM=xterm
fi

export OAR_FILE_NODES=$1
export OAR_JOBID=$2
export OAR_USER=$3
export OAR_WORKDIR=$5

export OAR_NODEFILE=$OAR_FILE_NODES
export OAR_O_WORKDIR=$OAR_WORKDIR
export OAR_NODE_FILE=$OAR_FILE_NODES
export OAR_RESOURCE_FILE=$OAR_FILE_NODES
export OAR_WORKING_DIRECTORY=$OAR_WORKDIR
export OAR_JOB_ID=$OAR_JOBID

#go to working directory
#( cd $6 >& /dev/null ) && cd $6
if ( cd $OAR_WORKING_DIRECTORY &> /dev/null )
then
    cd $OAR_WORKING_DIRECTORY
else
    #Cannot go into working directory
    exit 1
fi

if [ "$6" == "I" ]
then
    # Change TTY owner to the right user
    /bin/echo $$ | cat >> $9 && TTY=$(tty) && test -e $TTY && sudo chown $3:oar $TTY && sudo chmod 660 $TTY || exit 3
    $4
elif [ "$6" == "P" ]
then
    export OAR_STDOUT=$7
    export OAR_STDERR=$8
    
    #Test if we can write into stout and stderr files
    if ! ( > $OAR_STDOUT ) &> /dev/null || ! ( > $OAR_STDERR ) &> /dev/null
    then
        exit 2
    fi
    shift 9
    ($@ > $OAR_STDOUT) >& $OAR_STDERR
fi

exit 0

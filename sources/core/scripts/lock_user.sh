# $Id$
#It is a lock on idJob per user name
LOCKFILE=/tmp/.OARlockfile
MAXBLOCKTIME=120
SLEEPTIME=1

# take the lock
# $1: job ID for the reservation
# $2: user login
#return 1 if the lock times out
lock_file () {
    SPECIFICLOCKFILE=$LOCKFILE"_"$2
    RETURNCODE=0
    WAITINGTIME=0
    set -C
    until ( echo $1 > $SPECIFICLOCKFILE ) 2> /dev/null
    do
        echo "[LOCK] I am waiting for $WAITINGTIME seconds"
        if (( $WAITINGTIME > $MAXBLOCKTIME))
        then
            echo "[LOCK] It is enough, it may be a bug; I take the lock"
            rm -f $SPECIFICLOCKFILE
            RETURNCODE=1
        else
            sleep $SLEEPTIME
        fi
        ((WAITINGTIME= $WAITINGTIME + $SLEEPTIME))
    done
    set +C
    echo "[LOCK] Lock taken"
    return $RETURNCODE
}

#release semaphore
# $1: job ID for the reservation
# $2: user login
# return 1 if lock file is not right
unlock_file () {
    SPECIFICLOCKFILE=$LOCKFILE"_"$2
    RETURNCODE=0
    LOCKFILEID=`cat $SPECIFICLOCKFILE`
    if [ "x$LOCKFILEID" == "x$1"  ]
    then
        echo "[LOCK] I release the lock"
        rm -f $SPECIFICLOCKFILE
    else
        echo "[LOCK] this lock is not mine, execution was too long; maximum is $MAXBLOCKTIME"
        RETURNCODE=1
    fi
    return $RETURNCODE
}


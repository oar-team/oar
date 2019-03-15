#!/bin/bash
# Simple daemon to create a link between OAR jobs and CRIU checkpointing system 
# OAR jobs can create files into $CHECKPOINTS_DIR

CHECKPOINTS_DIR=/var/lib/checkpoints
TMP_DIR_FOR_DUMPS=/var/tmp

mkdir -p $CHECKPOINTS_DIR
chmod 1777 $CHECKPOINTS_DIR
mkdir -p $CHECKPOINTS_DIR.trash

while [ 1 ]
do
  # Checkpoint
  if [ "`ls $CHECKPOINTS_DIR/*.checkpoint 2>/dev/null`" != "" ]
  then
    for file in $CHECKPOINTS_DIR/*.checkpoint
    do
      job_id=$(basename $file .checkpoint)
      cpuset=$(ls -d /dev/cpuset/oar/*_$job_id)
      job_user=$(basename $cpuset _$job_id)
      ask_user=$(stat -c %U $file)
      if [ "$job_user" = "$ask_user" ]
      then
        dir=$(tail -1 $file)
        pid=$(head -1 $file)
	if [ "$pid" = "" ]
	then
	  echo "Empty pid, aborting dump"
	  mv $file $CHECKPOINTS_DIR.trash
        else
          proc_user=$(ps -o uname= -p $pid)
	  if [ "$job_user" = "$proc_user" ]
          then
            cd $dir
	    DIR=$(mktemp -d -p $TMP_DIR_FOR_DUMPS)
            echo "CRIU dump of job $job_id, pid $pid into $dir..."
            criu dump -D $DIR --shell-job -t $pid
            if [ $? = 0 ]
            then
	      if [ -d ./checkpoint ]
	      then
	        rm -rf checkpoint.old
	        mv -f ./checkpoint ./checkpoint.old
	      fi
	      mv $DIR ./checkpoint && touch checkpoint_ok
	      chown $job_user checkpoint
  	      echo "Checkpoint ok"
	    else
              echo "Checkpoint failed!"
	      rm -rf $DIR
            fi
            echo "CRIU dump of job $job_id ended"
            rm $file
	  else
	    echo "Process $pid does not belong to $job_user, but $proc_user, aborting."
	    mv $file $CHECKPOINTS_DIR.trash
	  fi
        fi
      else
        echo "Job $job_id of $job_user does not belongs to $ask_user!"
	mv $file $CHECKPOINTS_DIR.trash
      fi
    done
  fi

  # Resume
  if [ "`ls $CHECKPOINTS_DIR/*.resume 2>/dev/null`" != "" ]
  then
    for file in $CHECKPOINTS_DIR/*.resume
    do
      job_id=$(basename $file .resume)
      cpuset=$(ls -d /dev/cpuset/oar/*_$job_id)
      job_user=$(basename $cpuset _$job_id)
      ask_user=$(stat -c %U $file)
      if [ "$job_user" = "$ask_user" ]
      then
        dir=$(tail -1 $file)
        cd $dir
	rm -f checkpoint/pidfile
        echo "CRIU resume of job $job_id into $dir..."
        criu restore -D checkpoint --pidfile pidfile -d --shell-job
        if [ $? = 0 ]
        then
          echo "Resume ok!"
	  chown $job_user checkpoint/pidfile
          touch resume_ok
	  chown $job_user resume_ok
	  echo $(cat checkpoint/pidfile) >> $cpuset/tasks
        fi
        echo "CRIU resume of job $job_id ended"
        rm $file
      else
        echo "Job $job_id of $job_user does not belongs to $ask_user!"
	mv $file $CHECKPOINTS_DIR.trash
      fi
    done
  fi
  sleep 2
done

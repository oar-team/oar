#!/bin/sh

#Some parameters
TRACEDIR=/var/log/oar/
SERVER=edel-10
DEBUGFILE=epilogdebug.log
OAR_JOB_ID=$1
OAR_KEY=1
OAR_NODE_FILE=$3
TAKTUKCMD=0
mkdir -p $TRACEDIR

echo $OAR_JOB_ID  >$TRACEDIR/$DEBUGFILE
HOSTNAME=`hostname -a`

echo "hostname : $HOSTNAME ">>$TRACEDIR/$DEBUGFILE
uniq $OAR_NODE_FILE >>$TRACEDIR/$DEBUGFILE

NUMNODES=`uniq $OAR_NODE_FILE  | wc -l `

if [ "$NUMNODES" -lt "2" ]
then
        echo "One resource reserved">>$TRACEDIR/$DEBUGFILE
else
        echo "More than one resource reserved">>$TRACEDIR/$DEBUGFILE
	echo "Tranfering files from other nodes" >>$TRACEDIR/$DEBUGFILE
	for i in $(uniq $OAR_NODE_FILE) 
	do
		echo "node : $i">>$TRACEDIR/$DEBUGFILE
		if [ "$HOSTNAME" != "$i" ]
	        then
			echo "copying  file : /var/log/oar/trace-$i-$OAR_JOB_ID.log" >>$TRACEDIR/$DEBUGFILE				
			taktuk   -c "/usr/bin/ssh -p 6667" -m $i broadcast get [ $TRACEDIR/trace-$i-$OAR_JOB_ID.log ] [ $TRACEDIR/ ]
			taktuk   -c "/usr/bin/ssh -p 6667" -m $i broadcast exec [ 'for i in $(ls /var/log/oar/trace-MPI.node-*'$OAR_JOB_ID'*); do cat $i >>/tmp/tracempi'$OAR_JOB_ID'; rm $i; done' ]
			taktuk   -c "/usr/bin/ssh -p 6667" -m $i broadcast get [ /tmp/tracempi$OAR_JOB_ID ] [ $TRACEDIR/tracempi-$i-$OAR_JOB_ID.log ]
			#we erase the file
			taktuk   -c "/usr/bin/ssh -p 6667" -m $i broadcast exec - rm $TRACEDIR/trace-$i-$OAR_JOB_ID.log -
			#erasin the mpi trace 
			taktuk   -c "/usr/bin/ssh -p 6667" -m $i broadcast exec - rm /tmp/tracempi$OAR_JOB_ID -
			taktuk   -c "/usr/bin/ssh -p 6667" -m $i broadcast exec - 'rm '$TRACEDIR'/mpi-trace-write*' -
		else
			echo "we dont tranfer to this node $i" >>$TRACEDIR/$DEBUGFILE
			if [ -w $TRACEDIR ]
			then 
				echo "The directory is writable" >>$TRACEDIR/$DEBUGFILE
			else 
				echo "The directory is not writable">>$TRACEDIR/$DEBUGFILE
			fi

		        ###getting the MPI TRACE	
			for k in  $(ls /var/log/oar/trace-MPI.node-*$OAR_JOB_ID*)
			do 
				echo $k >> $TRACEDIR/$DEBUGFILE
				cat $k >> $TRACEDIR/tracempi-$i-$OAR_JOB_ID.log
			 	rm $k 
			done			 
			
			###Erasing the mpi-trace-write
                        rm $TRACEDIR/mpi-trace-write

		fi
		
	done
fi

cd $TRACEDIR

for i in $(uniq $OAR_NODE_FILE)
do
	#taktuk  -m $SERVER broadcast put [ $TRACEDIR/trace-$i-$OAR_JOB_ID.log ] [ $TRACEDIR/ ]
	tar -uvf  $TRACEDIR/trace-$OAR_JOB_ID.tar trace-$i-$OAR_JOB_ID.log
	tar -uvf  $TRACEDIR/trace-$OAR_JOB_ID.tar tracempi-$i-$OAR_JOB_ID.log  
	#taktuk  -m $SERVER broadcast put [ $TRACEDIR/tracempi-$i-$OAR_JOB_ID.log ] [ $TRACEDIR/ ]
	rm trace-$i-$OAR_JOB_ID.log
	rm tracempi-$i-$OAR_JOB_ID.log
done


bzip2 $TRACEDIR/trace-$OAR_JOB_ID.tar
taktuk  -c "/usr/bin/ssh -p 6667" -m $SERVER broadcast put [ $TRACEDIR/trace-$OAR_JOB_ID.tar.bz2 ] [ $TRACEDIR/ ]
rm $TRACEDIR/trace-$OAR_JOB_ID.tar.bz2

#ersaing the file in the node
#rm $TRACEDIR/trace-$HOSTNAME-$OAR_JOB_ID.log
echo "end collect process ">> $TRACEDIR/$DEBUGFILE


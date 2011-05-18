#!/bin/sh

#Some parameters
TRACEDIR=/var/log/oar
SERVER=adonis-5
DEBUGFILE=epilogdebug.log
OAR_JOB_ID=$1
OAR_KEY=1
OAR_NODE_FILE=$3


echo $OAR_JOB_ID  >$TRACEDIR/$DEBUGFILE
HOSTNAME=`cat /etc/hostname `

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
			taktuk -m $i broadcast get [ $TRACEDIR/trace-$i-$OAR_JOB_ID.log ] [ $TRACEDIR/ ]
			#we erase the file
			taktuk -m $i broadcast exec - rm $TRACEDIR/trace-$i-$OAR_JOB_ID.log -
		else
			echo "we dont tranfer to this node $i" >>$TRACEDIR/$DEBUGFILE
		fi
	done
fi

for i in $(uniq $OAR_NODE_FILE)
do
	taktuk -m $SERVER broadcast put [ $TRACEDIR/trace-$i-$OAR_JOB_ID.log ] [ $TRACEDIR/ ]
	rm $TRACEDIR/trace-$i-$OAR_JOB_ID.log
done

#ersaing the file in the node
#rm $TRACEDIR/trace-$HOSTNAME-$OAR_JOB_ID.log
echo "end collect process ">> $TRACEDIR/$DEBUGFILE


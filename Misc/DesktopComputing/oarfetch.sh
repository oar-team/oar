#!/bin/bash
# this script allows to retrieve desktop computing jobs results
# $Id: oarfetch.sh 408 2007-03-01 12:29:17Z neyron $

usage() {
	cat <<EOF
Usage: `basename $0` <jobId>
Please provide the Id of the desktop computing job you want to retrieve the results of.
EOF
	exit 1
}

JOBID=$1
[ -n "$JOBID" ] || usage

SERVER_HOSTNAME=`grep SERVER_HOSTNAME /etc/oar.conf| cut -f2 -d=`
ssh -T $SERVER_HOSTNAME <<SSHEOF | sudo -u $SUDO_USER tar xvz 2> /dev/null
DB_HOSTNAME=\`grep DB_HOSTNAME /etc/oar.conf | cut -f2 -d=\`
DB_BASE_NAME=\`grep DB_BASE_NAME /etc/oar.conf | cut -f2 -d=\`
DB_BASE_LOGIN=\`grep DB_BASE_LOGIN /etc/oar.conf | cut -f2 -d=\`
DB_BASE_PASSWD=\`grep DB_BASE_PASSWD /etc/oar.conf | cut -f2 -d=\`
JOBUSER=\$(mysql -u\$DB_BASE_LOGIN -p\$DB_BASE_PASSWD -h\$DB_HOSTNAME <<EOF | tail +2
connect \$DB_BASE_NAME
select user from jobs where idJob=$JOBID;
exit
EOF)
if [ "x\$JOBUSER" != "x$SUDO_USER" ]; then
	echo "Sorry, you ($SUDO_USER) are not the owner of job $JOBID." 1>&2
	exit 3
fi
STAGEOUT_DIR=\`grep STAGEOUT_DIR /etc/oar.conf | cut -f2 -d=\`
STAGEOUT=\$STAGEOUT_DIR/$JOBID.tgz
if [ ! -r \$STAGEOUT ]; then 
	echo "Sorry, no stageout file found for job $JOBID." 1>&2
	exit 4
fi
cat \$STAGEOUT
exit 0
SSHEOF
if [ $? != 0 ]; then
	echo "Error !" 2>&1
	exit 1
fi

#
exit 0
#

read -p "Purge this job result data on server ? [Y/n]" -n 1 -s PURGE
if [ "x$PURGE" != "xn" -a "x$PURGE" != "xN" ]; then
	ssh -T $SERVER_HOSTNAME <<EOF
STAGEOUT_DIR=\`grep STAGEOUT_DIR /etc/oar.conf| cut -f2 -d=\`
STAGEOUT=\$STAGEOUT_DIR/$JOBID.tgz
rm \$STAGEOUT
EOF
fi
echo 

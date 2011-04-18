#!/bin/bash
#
# oar-server          Start/Stop the oar server daemon.
#
# chkconfig: 2345 90 10
# description: This script starts or stops the OAR resource manager
# processname: Almighty
# config: /etc/oar/oar.conf
# pidfile: /var/run/oar-server.pid
#
# LSB compliant header
### BEGIN INIT INFO                                                                                                                          
# Provides:          oar-server
# Required-Start:    $network $local_fs $remote_fs $all
# Required-Stop:     $remote_fs
# Default-Start:     2 3 4 5
# Default-Stop:      0 1 6
# Short-Description: OAR server init script                                                                                                  
# Description:       This script starts or stops the OAR resource manager           
#                                                                                                                                            
### END INIT INFO
# Author: Bruno Bzeznik <Bruno.Bzeznik@imag.fr>
#

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/usr/sbin:/bin:/usr/bin
DESC="OAR resource manager (server)"
NAME=oar-server
DAEMON=/usr/sbin/oar-server
DAEMON_NAME=Almighty
DAEMON_ARGS=""
PIDFILE=/var/run/$NAME.pid
SCRIPTNAME=/etc/init.d/$NAME
RETVAL=0

test -x $DAEMON || exit 0

# Source function library.
. /lib/lsb/init-functions


# Set sysconfig settings
[ -f /etc/sysconfig/oar-server ] && . /etc/sysconfig/oar-server


start() {
        echo -n "Starting $DESC: "
        CHECK_STRING=`oar_checkdb 2>&1`
        if [ "$?" -ne "0" ]
        then
          echo
          echo "  Database is not ready! Maybe not initiated or no DBMS running?"
          echo "  You must have a running MySQL or Postgres server."
          echo "  To init the DB, run oar_mysql_db_init or oar_psql_db_init"
          echo "  Also check the DB_* variables in /etc/oar/oar.conf"
          echo -n "  The error was: "
          echo $CHECK_STRING
          log_failure_msg
          exit 1
        fi
        pidofproc -p $PIDFILE $DAEMON_NAME > /dev/null && { echo -n " already running" ; log_success_msg; exit 0;}
        start_daemon $DAEMON $DAEMON_OPTS
        RETVAL=$?
        if [ $RETVAL -eq 0 ]; then
                log_success_msg
        else
                log_failure_msg
        fi
}
stop() {
        echo -n "Stopping $DESC: "
        PID=`pidofproc -p $PIDFILE $DAEMON_NAME` 
        if [ "$?" = "0" ]
        then
          kill $PID
        else
          killall Almighty 2>/dev/null
        fi
        # Wait
        let max_wait=30
        let c=0
        while [ "`ps awux |grep 'oar.*Almighty'|grep -v grep`" \!= "" -a $c -lt $max_wait ]; do sleep 1; let c++; echo -n "."; done
        # Kill -9 if always there
        if [ $c -eq $max_wait ]
        then
          echo "forced kill"
          killall -9 Almighty
          killall -9 sarko
        fi
	rm -f $PIDFILE
        log_success_msg
}

case "$1" in
  start)
        start
        ;;
  stop)
        stop
        exit 0
        ;;
  restart|force-reload|restart)
        stop
        sleep 1
        start
        ;;
  *)
        echo $"Usage: $0 {start|stop|restart}"
        RETVAL=3
esac
exit $RETVAL


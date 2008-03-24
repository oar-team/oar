# $Id: $
#! /bin/bash
#
# oar-server          Start/Stop the oar server daemon.
#
# chkconfig: 2345 99 01
# description: OAR is a resource manager (or batch scheduler) for large computing clusters.
# processname: Almighty
# config: /etc/oar/oar.conf
# pidfile: /var/run/oar-server.pid

RETVAL=0
DAEMON=/usr/sbin/oar-server
DESC=oar-server
PIDFILE=/var/run/oar-server.pid

test -x $DAEMON || exit 0

# Source function library.
. /etc/init.d/functions

# Set sysconfig settings
[ -f /etc/sysconfig/oar ] && . /etc/sysconfig/oar

start() {
        echo -n "Starting $DESC: "
        daemon $DAEMON $DAEMON_OPTS && success || failure
        RETVAL=$?
        echo
}
stop() {
        echo -n "Stopping $DESC: "
        if [ -n "`pidfileofproc $DAEMON`" ]; then
            killproc $DAEMON
            sleep 1
            killall Almighty 2>/dev/null
            sleep 1
            killall -9 Almighty 2>/dev/null
            RETVAL=3
        else
            failure "Stopping $DESC"
        fi
        RETVAL=$?
        echo
}

case "$1" in
  start)
        start
        ;;
  stop)
        stop
        ;;
  restart|force-reload|restart)
        stop
        sleep 1
        start
        ;;
  status)
        status $DAEMON
        ;;
  *)
        echo $"Usage: $0 {start|stop|status|restart}"
        RETVAL=3
esac
exit $RETVAL


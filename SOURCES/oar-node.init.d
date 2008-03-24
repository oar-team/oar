# $Id: $
#! /bin/bash
#
# oar-node          Start/Stop the oar node services
#
# chkconfig: 2345 99 01
# description: OAR is a resource manager (or batch scheduler) for large computing clusters.
# processname: 
# config: /etc/oar/sshd_config
# pidfile: /var/run/oar-node.pid

RETVAL=0
DESC="OAR dedicated SSH server"
OAR_SSHD_CONF="/etc/oar/sshd_config"
SSHD_OPTS="-f $OAR_SSHD_CONF -o PidFile=/var/lib/oar/oar_sshd.pid"

# Source function library.
. /etc/init.d/functions

# Set sysconfig settings
[ -f /etc/sysconfig/oar ] && . /etc/sysconfig/oar

start() {
        echo -n "Starting $DESC: "
        if [ -f "$OAR_SSHD_CONF" ] ; then
            daemon --pidfile /var/lib/oar/oar_sshd.pid /usr/sbin/sshd $SSHD_OPTS && success || failure
            RETVAL=$?
            echo
        else 
            failure $"Starting $DESC"
        fi
}
stop() {
        echo -n "Stopping $DESC: "
        if [ -n "`cat /var/lib/oar/oar_sshd.pid 2>/dev/null`" ]; then
            killproc -p /var/lib/oar/oar_sshd.pid
            RETVAL=3
        else
            failure $"Stopping $DESC"
        fi
        RETVAL=$?
        echo
}
reload() {
        echo -n $"Reloading $DESC: "
	if [ -n "`cat /var/lib/oar/oar_sshd.pid 2>/dev/null`" ]; then
	    killproc -p /var/lib/oar/oar_sshd.pid -HUP
        else
	    failure $"Reloading $DESC"
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
  reload)
        reload
        ;;
  restart|force-reload|restart)
        stop
        sleep 1
        start
        ;;
  *)
        echo $"Usage: $0 {start|stop|reload|restart}"
        RETVAL=3
esac
exit $RETVAL


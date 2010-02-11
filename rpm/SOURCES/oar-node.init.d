# $Id: oar-node.init.d 1285 2008-03-27 15:54:26Z bzizou $
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


start_oar_node() {
    echo " * Edit start_oar_node function in /etc/sysconfig/oar-node if you want"
    echo "   to perform a specific action (e.g. to switch the node to Alive)"
}

stop_oar_node() {
    echo " * Edit stop_oar_node function in /etc/sysconfig/oar-node if you want"
    echo "   to perform a specific action (e.g. to switch the node to Absent)"
}


# Set sysconfig settings
[ -f /etc/sysconfig/oar-node ] && . /etc/sysconfig/oar-node

start() {
        echo -n "Starting $DESC: "
        if [ -f "$OAR_SSHD_CONF" ] ; then
            daemon -20 --force /usr/sbin/sshd $SSHD_OPTS && success || failure
            RETVAL=$?
            echo
        else 
            failure $"Starting $DESC"
        fi
}
stop() {
        echo -n "Stopping $DESC: "
        if [ -n "`cat /var/lib/oar/oar_sshd.pid 2>/dev/null`" ]; then
            kill `cat /var/lib/oar/oar_sshd.pid` && success || failure
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
        start_oar_node
        ;;
  stop)
        stop_oar_node
        stop
        ;;
  reload)
        reload
        ;;
  restart|force-reload|restart)
        stop_oar_node
        stop
        sleep 1
        start_oar_node
        start
        ;;
  *)
        echo $"Usage: $0 {start|stop|reload|restart}"
        RETVAL=3
esac
exit $RETVAL


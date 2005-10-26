#!/bin/sh
# $Id: oar-server.init.d,v 1.3 2005/06/08 14:11:34 capitn Exp $
#
# oarserver:       Starts the oarserver Daemon
#
# Version:      ???
#
# chkconfig: 345  99 01
# description: This is the OAR server
# processname: ???
# config: /etc/oar.conf
# Source function library.
. /etc/rc.d/init.d/functions

# See how we were called.
case "$1" in
  start)
		daemon /usr/sbin/oar-server 
    echo
    ;;
  stop)
		killproc oar-server
    echo
    ;;
  restart)
                $0 stop
                sleep 1
                $0 start
                ;;
  *)
    gprintf "*** Usage: oar {start|restart|stop}\n"
    exit 1
esac

exit $RETVAL


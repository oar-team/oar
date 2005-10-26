#!/bin/sh
# $Id: initd_oar.sh,v 1.2 2004/08/24 16:10:34 neyron Exp $
# script for mandrake
# Source function library.
. /etc/rc.d/init.d/functions

RETVAL=0

# See how we were called.
case "$1" in
  start)
        su - oar -c "/usr/bin/oarnodesetting -s Alive"
        touch /var/lock/subsys/oar
        echo
        ;;
  stop)
        su - oar -c "/usr/bin/oarnodesetting -s Absent"
        rm -f /var/lock/subsys/oar
        echo
        ;;
  kill)
        /usr/bin/oarnodesetting -s Absent
        rm -f /var/lock/subsys/oar
        echo
        ;;
  *)
        gprintf "*** Usage: oar {start|stop|kill}\n"
        exit 1
esac

exit $RETVAL


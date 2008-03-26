# $Id$
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
CONFIG=/etc/oar/oar.conf

test -x $DAEMON || exit 0

# Source function library.
. /etc/init.d/functions

# Set sysconfig settings
[ -f /etc/sysconfig/oar ] && . /etc/sysconfig/oar

check_sql() {
        echo -n "Checking oar SQL base: "
	if [ -f $CONFIG ] && . $CONFIG ; then
           :
        else
          echo -n "Error loading $CONFIG"
          failure
          exit 1
        fi
        if [ "$DB_TYPE" = "mysql" -o "$DB_TYPE" = "Pg" ] ; then
          export PERL5LIB="/usr/lib/oar"
          export OARCONFFILE="$CONFIG"
          perl <<EOS && success || failure 
          use oar_iolib;
          if (iolib::connect_db("$DB_HOSTNAME","$DB_BASE_NAME","$DB_BASE_LOGIN","$DB_BASE_PASSWD",0)) { exit 0; }
          else { exit 1; }
EOS
        else
          echo -n "Unknown $DB_TYPE database type"
          failure
          exit 1
        fi
}

sql_init_error_msg (){
  echo
  echo "OAR database seems to be unreachable." 
  echo "Did you forget to initialize it or to configure the oar.conf file?"
  echo "See http://oar.imag.fr/docs/manual.html#configuration-of-the-cluster for more infos"
  exit 1
}

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
            failure $"Stopping $DESC"
        fi
        RETVAL=$?
        echo
}

case "$1" in
  start)
        check_sql || sql_init_error_msg
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


#! /bin/sh

### BEGIN INIT INFO
# Provides:         oar-desktop-computing-agent
# Required-Start:   $network $local_fs $remote_fs
# Required-Stop:
# Default-Start:    2 3 4 5
# Default-Stop:     0 1 6
# Short-Description:    OAR desktop computing agent daemon starting
### END INIT INFO

PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
NAME=oar-desktop-computing-agent
DESC=desktop-computing-agent

case "$1" in
  start)
    echo "Starting $DESC:"
    if start-stop-daemon --start -N "-20" --quiet --pidfile /var/lib/oar/oar_agent.pid --exec /usr/sbin/oar-agent-daemon -- start ; then
            echo " * OAR desktop computing agent daemon started."
    else
            echo " * Failed to start the computing agent daemon."
            exit 1
    fi
    ;;
  stop)
    echo "Stopping $DESC: "
    if start-stop-daemon --stop --quiet --pidfile /var/lib/oar/oar_agent.pid; then
            echo " * OAR desktop computing agent daemon stopped."
    else
            echo " * Failed to stop desktop computing agent daemon."
    fi
    ;;
  reload|force-reload|restart)
        $0 stop
        sleep 1
        $0 start
        ;;
  *)
    N=/etc/init.d/$NAME
    echo "Usage: $N {start|restart|stop}" >&2
    exit 1
    ;;
esac

exit 0

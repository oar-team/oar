Index: oar/setup/init.d/oar-node.in
===================================================================
--- oar.orig/setup/init.d/oar-node.in
+++ oar/setup/init.d/oar-node.in
@@ -80,6 +80,7 @@ do_start() {
         exit 2
     fi
     if [ -f "$OAR_SSHD_CONF" ] ; then
+        mkdir -p /var/run/sshd
         if start_daemon -p $PIDFILE -n "-20" /usr/sbin/sshd $SSHD_OPTS; then
             # redhat world
             [ -d /var/lock/subsys/ ] && touch /var/lock/subsys/$NAME

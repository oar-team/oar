#
# cron.d/oar-node -- schedules periodic checks of the local node by running
# every scripts of the /etc/oar/check.d directory, if any.
# 
# $Id$

# By default, run every hours
0 * * * * root [ -x /usr/lib/oar/oarnodecheckrun ] && /usr/lib/oar/oarnodecheckrun

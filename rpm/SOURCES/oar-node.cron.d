#
# cron.d/oar-node -- schedules periodic checks of the local node by running
# every scripts of the /etc/oar/check.d directory, if any.
# 
# $Id: oar-node.cron.d 1272 2008-03-26 13:51:38Z bzizou $

# By default, run every hours
0 * * * * root [ -x /usr/lib/oar/oarnodecheckrun ] && /usr/lib/oar/oarnodecheckrun

#
# cron.d/oar-server -- schedules OAR accounting data mining
# 
# $Id: oar-server.cron.d 1272 2008-03-26 13:51:38Z bzizou $

# By default, run every hours
0 * * * * root [ -x /usr/sbin/oaraccounting ] && /usr/sbin/oaraccounting

#
# cron.d/oar-server -- schedules OAR accounting data mining
# 
# $Id$

# By default, run every hours
0 * * * * root [ -x /usr/sbin/oaraccounting ] && /usr/sbin/oaraccounting

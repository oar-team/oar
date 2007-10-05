#!/bin/sh
# $Id$

OARDIR=
OARUSER=

PERL5LIB=$OARDIR
OARCONFFILE=/etc/oar/oar.conf
OARXAUTHLOCATION=
OARSHELLWRAPPER=/etc/oar/shell_user_wrapper.sh
#DBI_PROFILE=2
#export DBI_PROFILE
export PERL5LIB
export OARDIR
export OARUSER
export OARCONFFILE
export OARXAUTHLOCATION
export OARSHELLWRAPPER

exec $OARDIR/`basename $0` "$@"

#!/bin/sh
# $Id$

OARDIR=
OARUSER=

PERL5LIB=$OARDIR
OARCONFFILE=/etc/oar/oar.conf
OARXAUTHLOCATION=
export PERL5LIB
export OARDIR
export OARUSER
export OARCONFFILE
export OARXAUTHLOCATION

exec $OARDIR/`basename $0` "$@"

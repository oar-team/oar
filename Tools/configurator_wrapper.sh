#!/bin/sh
# $Id$

OARDIR=
OARUSER=

PERL5LIB=$OARDIR
OARCONFFILE=/etc/oar.conf
export PERL5LIB
export OARDIR
export OARUSER
export OARCONFFILE

exec $OARDIR/`basename $0` "$@"

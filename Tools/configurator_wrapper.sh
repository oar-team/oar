#!/bin/sh

OARDIR=
OARUSER=

PERL5LIB=$OARDIR
export PERL5LIB
export OARDIR
export OARUSER
export OARCONFFILE=/etc/oar.conf

exec $OARDIR/`basename $0` "$@"

#!/bin/sh
# $Id: sudowrapper.sh,v 1.11 2005/10/24 13:03:30 capitn Exp $

OARDIR=
OARUSER=

export OARLIB=$OARDIR
export OARDIR
export OARUSER

exec sudo -u $OARUSER $OARDIR/`basename $0` "$@"

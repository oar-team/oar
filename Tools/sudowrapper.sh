#!/bin/sh
# $Id$

OARDIR=
OARUSER=
OARCMD=

exec sudo -H -u $OARUSER $OARDIR/cmds/$OARCMD "$@"

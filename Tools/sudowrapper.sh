#!/bin/sh

OARDIR=
OARUSER=
OARCMD=

exec sudo -H -u $OARUSER $OARDIR/cmds/$OARCMD "$@"

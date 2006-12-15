#!/bin/sh

OARDIR=
OARUSER=
OARCMD=

exec sudo -u $OARUSER $OARDIR/cmds/$OARCMD "$@"

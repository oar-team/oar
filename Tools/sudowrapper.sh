#!/bin/sh

OARDIR=
OARUSER=

exec sudo -u $OARUSER $OARDIR/cmds/`basename $0` "$@"

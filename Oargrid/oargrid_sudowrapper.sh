#!/bin/bash
# $Id: oargrid_sudowrapper.sh,v 1.1 2005/03/14 09:59:37 capitn Exp $

OARGRIDDIR=
OARGRIDUSER=

exec sudo -u $OARGRIDUSER $OARGRIDDIR/cmds/`basename $0` "$@"

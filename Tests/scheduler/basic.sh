#!/bin/bash
# $Id$
# Basic example of test scenario

MYTEST=$PWD/${0#$PWD/}
BASEDIR=${MYTEST%/*}
BUILDDIR=$BASEDIR/build
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
SRCDIR=$BASEDIR/src
DEBUG=1

. $SCRIPTDIR/base.sh
. $SCRIPTDIR/oar.sh
. $SCRIPTDIR/mysql.sh

base_cleanup
base_prepare
oar_install
oar_config
mysql_check_oar_conf
mysql_init
mysql_start
mysql_create_oar_db
mysql_inject_oar_data $DATADIR/mysql_structure.sql
mysql_inject_oar_data $DATADIR/default_data.sql
mysql_inject_oar_data $DATADIR/mysql_default_admission_rules.sql
oar_run_scheduler
mysql_stop



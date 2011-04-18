#!/bin/bash
# $Id: 001_advance_reservation_with_absent_resource.sh 1712 2008-10-17 08:41:53Z neyron $
# Basic example of test scenario

BASENAME=${0#$PWD/}
BASEPREFIX=${BASENAME%%_*}
BASEDIR=$PWD/${BASENAME%/*}
BUILDDIR=$BASEDIR/build
DATADIR=$BASEDIR/data
SCRIPTDIR=$BASEDIR/scripts
SRCDIR=$BASEDIR/src
DEBUG=1

. $SCRIPTDIR/base.sh
. $SCRIPTDIR/oar.sh
. $SCRIPTDIR/mysql.sh

test_cleanup
test_prepare
oar_install
oar_copy_config
oar_source_config
mysql_check_oar_conf
mysql_copy_config
mysql_init
mysql_start "2008-10-23 15:00:00"
mysql_create_oar_db
mysql_query_from_file heavy_load.sql
oar_run_scheduler
THRESHOLD=42
test_exit_status "Scheduler performance test (threshold = $THRESHOLD)" \
	mysql_query "SELECT count\(*\) FROM gantt_jobs_predictions" \| \( read \; test \$REPLY -ge $THRESHOLD \)
mysql_stop

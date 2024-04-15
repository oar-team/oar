#!/bin/bash
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
mysql_start "2008-10-09 18:00:00"
mysql_create_oar_db
mysql_query_from_file advance_reservation_with_dead_resource.sql
oar_run_scheduler
test_exit_status "Scheduler before advance reseration start time" \
	mysql_query "SELECT state, reservation FROM jobs WHERE job_id = 1" \| grep -q -e "^Waiting[[:space:]]Scheduled$"
mysql_stop
mysql_start "2008-10-09 20:01:00"
oar_run_scheduler
test_exit_status "Scheduler at advance reseration start time" \
	mysql_query "SELECT state, reservation FROM jobs WHERE job_id = 1" \| grep -q -e "^toLaunch[[:space:]]Scheduled$"
mysql_stop

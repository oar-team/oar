#!/bin/bash
# $Id$
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
mysql_start
mysql_create_oar_db
mysql_query_from_file mysql_structure.sql
mysql_query_from_file default_data.sql
mysql_query_from_file mysql_default_admission_rules.sql
oar_run_scheduler
mysql_stop
test_print_ok "Sanity test is ok"



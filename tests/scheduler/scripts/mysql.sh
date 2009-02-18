#!/bin/bash
# $Id$
# function set to handle mysql within tests

BUILDDIR=${BUILDDIR:-build}
DATADIR=${DATADIR:-data}

mysql_check_oar_conf() {
	if [ "x$DB_HOSTNAME" != "x127.0.0.1" ]; then
		echo "Please set DB_HOSTNAME=\"127.0.0.1\" in oar.conf (localhost means unix-socket)"
		exit 1
	fi
	debug "OAR config is ok"
}

mysql_copy_config() {
	local FILE=${1:-my.cnf}
	if [ -r "$DATADIR/${BASEPREFIX}_$FILE" ]; then
		debug "Copying MySQL config file from $FILE"
		mkdir -p $BUILDDIR/etc/mysql
		cp $DATADIR/${BASEPREFIX}_$FILE $BUILDDIR/etc/mysql/my.cnf
		debug "done"	
	else
		echo "Can't read file: $FILE"
		exit 1
	fi
}

mysql_init() {
	debug "Initializing MySQL data..."
	mysql_install_db --no-defaults --datadir=$BUILDDIR/var/lib/mysql > /dev/null 2>&1
	debug "done"
}

mysql_start() {
	if ! [ -r $BUILDDIR/var/run/mysqld.pid ]; then
		if [ -z "$1" ]; then
			debug "Starting MySQL..."
			mysqld_safe --defaults-file=$BUILDDIR/etc/mysql/my.cnf \
				--user=$USER \
				--pid-file=$BUILDDIR/var/run/mysqld.pid \
				--socket=$BUILDDIR/var/run/mysqld.sock \
				--port=${DB_PORT:-3306} \
				--datadir=$BUILDDIR/var/lib/mysql \
				> /dev/null 2>&1 &
		else
			debug "Starting MySQL at time $@..."
			faketime -f "$@" mysqld_safe --defaults-file=$BUILDDIR/etc/mysql/my.cnf \
				--user=$USER \
				--pid-file=$BUILDDIR/var/run/mysqld.pid \
				--socket=$BUILDDIR/var/run/mysqld.sock \
				--port=${DB_PORT:-3306} \
				--datadir=$BUILDDIR/var/lib/mysql \
				> /dev/null 2>&1 &
		fi
		sleep 1
		while ! mysqladmin --no-defaults \
			--socket=$BUILDDIR/var/run/mysqld.sock \
			ping > /dev/null 2>&1 ; do
			sleep 1
			debug "Not there yet..."
		done
		debug "done"
	else
		debug "MySQL is already running (pid file found)"
	fi
}

mysql_create_oar_db() {
	debug "Creating OAR database..."
	cat <<EOF | mysql --user root --socket $BUILDDIR/var/run/mysqld.sock 
create database $DB_BASE_NAME;
grant all privileges on $DB_BASE_NAME.* to "$DB_BASE_LOGIN"@"localhost" identified by "$DB_BASE_PASSWD";
grant all privileges on $DB_BASE_NAME.* to "$DB_BASE_LOGIN"@"%" identified by "$DB_BASE_PASSWD";
EOF
	debug "done"
}

mysql_query() {
	debug "Running query: $*"
	echo "$*" | mysql -N -r -u $DB_BASE_LOGIN -p$DB_BASE_PASSWD -h$DB_HOSTNAME -P${DB_PORT:-3306} $DB_BASE_NAME
	debug "done"
}

mysql_query_from_file() {
	local FILE=$1
	if [ -r "$DATADIR/${BASEPREFIX}_$FILE" ]; then
		debug "Running query form file $FILE"
		cat $DATADIR/${BASEPREFIX}_$FILE | mysql -N -u $DB_BASE_LOGIN -p$DB_BASE_PASSWD -h$DB_HOSTNAME -P${DB_PORT:-3306} $DB_BASE_NAME
		debug "done"
	else
		echo "Can't read file: $FILE"
		exit 1
	fi
}

mysql_stop() {
	if [ -r $BUILDDIR/var/run/mysqld.pid ]; then
		MYSQL_PID=$(< $BUILDDIR/var/run/mysqld.pid)
		debug "Stopping MySQL, process $MYSQL_PID..."
		kill $MYSQL_PID
		while mysqladmin --no-defaults \
			--socket=$BUILDDIR/var/run/mysqld.sock \
			ping  > /dev/null 2>&1 ; do
			debug "MySQL still there..."
			sleep 1
		done
		while [ -e "$BUILDDIR/var/run/mysqld.pid" ]; do
			debug "Pidfile still there..."
			sleep 1
		done
		debug "done"
	else
		echo "No pid found, is MySQL really running ?"
		exit 1
	fi
}

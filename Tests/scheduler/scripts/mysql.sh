#!/bin/bash
# $Id$
# function set to handle mysql within tests

DEBUG=${DEBUG:r-=0}
BUILDDIR=${BUILDDIR:-build}
DATADIR=${DATADIR:-data}

debug() {
	if [ $DEBUG -gt 0 ]; then
		echo $1
	fi
}

mysql_check_oar_conf() {
	if [ "x$DB_HOSTNAME" != "x127.0.0.1" ]; then
		echo "Please set DB_HOSTNAME=\"127.0.0.1\" in oar.conf"
		exit 1
	fi
	debug "OAR config is ok"
}

mysql_init() {
	debug "Setup MySQL config..."
	mkdir -p $BUILDDIR/etc/mysql
	cp $DATADIR/etc/mysql/my.cnf $BUILDDIR/etc/mysql/my.cnf
	debug "done"
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
			debug "No there yet..."
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

mysql_inject_oar_data() {
	if [ -r "$1" ]; then
		debug "Injecting data from $1"
		cat $1 | mysql -u $DB_BASE_LOGIN -p$DB_BASE_PASSWD -h$DB_HOSTNAME -P${DB_PORT:-3306} $DB_BASE_NAME
		debug "done"
	else
		echo "Can't read file: $1"
		exit 1
	fi
}

mysql_stop() {
	if [ -r $BUILDDIR/var/run/mysqld.pid ]; then
		MYSQL_PID=$(< $BUILDDIR/var/run/mysqld.pid)
		debug "Stopping process $MYSQL_PID..."
		kill $MYSQL_PID
		while mysqladmin --no-defaults \
			--socket=$BUILDDIR/var/run/mysqld.sock \
			ping  > /dev/null 2>&1 ; do
			debug "Still there..."
			sleep 1
		done
		debug "done"
	else
		echo "No pid found, is MySQL really running ?"
		exit 1
	fi
}

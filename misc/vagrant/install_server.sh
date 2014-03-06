#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
set -x

## Server node
# Package list
# dev dependencies
PKG="avahi-daemon libnss-mdns rsync"
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
# Common dependencies
PKG="$PKG perl perl-base openssh-client openssh-server libdbi-perl libsort-versions-perl taktuk"
# PostgreSQL dependencies
PKG="$PKG postgresql postgresql-client libdbd-pg-perl"


apt-get update
apt-get install -y --force-yes $PKG
apt-get clean

# install oar server
rsync -ah /home/vagrant/oar/ /tmp/oar-src/
make -C /tmp/oar-src/ clean
make -C /tmp/oar-src/ PREFIX=/usr/local server-build
make -C /tmp/oar-src/ PREFIX=/usr/local server-install
make -C /tmp/oar-src/ PREFIX=/usr/local server-setup

## Configure server initd
cp /usr/local/share/oar/oar-server/init.d/oar-server /etc/init.d/
cp /usr/local/share/oar/oar-server/default/oar-server /etc/default/
update-rc.d oar-server defaults

# Initialize postgres
su postgres -c "psql -c 'DROP DATABASE IF EXISTS oar'"
su postgres -c "psql -c 'DROP USER IF EXISTS oar'"
su postgres -c "psql -c 'DROP USER IF EXISTS oar_ro'"

PGSQL_CONFDIR=/etc/postgresql/9.1/main/
# Configure PostgreSQL to listen for remote connections:
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" $PGSQL_CONFDIR/postgresql.conf

# Configure PostgreSQL to accept remote connections (from any host):
cat >> $PGSQL_CONFDIR/pg_hba.conf <<EOF
# Accept all IPv4 connections - CHANGE THIS!!!
host    all         all         0.0.0.0/0             md5
EOF

service postgresql restart

# Edit oar.conf
sed -e 's/^LOG_LEVEL\=\"2\"/LOG_LEVEL\=\"3\"/' -i /etc/oar/oar.conf

sed -e 's/^DB_HOSTNAME\=\"localhost\"/DB_HOSTNAME\=\"server\"/' -i /etc/oar/oar.conf
sed -e 's/^SERVER_HOSTNAME\=\"localhost\"/SERVER_HOSTNAME\=\"server\"/' -i /etc/oar/oar.conf

sed -e 's/^#\(TAKTUK_CMD\=\"\/usr\/bin\/taktuk \-t 30 \-s\".*\)/\1/' -i /etc/oar/oar.conf
sed -e 's/^#\(PINGCHECKER_TAKTUK_ARG_COMMAND\=\"broadcast exec timeout 5 kill 9 \[ true \]\".*\)/\1/' -i /etc/oar/oar.conf

sed -e 's/^\(DB_TYPE\)=.*/\1="Pg"/' -i /etc/oar/oar.conf
sed -e 's/^\(DB_PORT\)=.*/\1="5432"/' -i /etc/oar/oar.conf

sed -e 's/^#\(JOB_RESOURCE_MANAGER_PROPERTY_DB_FIELD\=\"cpuset\".*\)/\1/' -i /etc/oar/oar.conf
sed -e 's/^#\(JOB_RESOURCE_MANAGER_FILE\=\"\/etc\/oar\/job_resource_manager\.pl\".*\)/\1/' -i /etc/oar/oar.conf
sed -e 's/^#\(CPUSET_PATH\=\"\/oar\".*\)/\1/' -i /etc/oar/oar.conf

sed -e 's/^\(DB_BASE_PASSWD\)=.*/\1="oar"/' -i /etc/oar/oar.conf
sed -e 's/^\(DB_BASE_LOGIN\)=.*/\1="oar"/' -i /etc/oar/oar.conf
sed -e 's/^\(DB_BASE_PASSWD_RO\)=.*/\1="oar_ro"/' -i /etc/oar/oar.conf
sed -e 's/^\(DB_BASE_LOGIN_RO\)=.*/\1="oar_ro"/' -i /etc/oar/oar.conf


# Create OAR database
/usr/local/sbin/oar-database --create --db-is-local --db-admin-user root

sed -e 's/#exit/exit/' -i /etc/oar/job_resource_manager.pl

service oar-server restart

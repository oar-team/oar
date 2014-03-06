#!/bin/bash
export DEBIAN_FRONTEND=noninteractive

# Package list
# dev dependencies
PKG="avahi-daemon libnss-mdns inotify-tools rsync"
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
## Frontend nodes
# Common dependencies
PKG="$PKG perl perl-base openssh-client openssh-server libdbi-perl taktuk"
# PostgreSQL dependencies
PKG="$PKG postgresql-client libdbd-pg-perl"
## Visualization node
# Common dependencies
PKG="$PKG perl perl-base ruby libgd-ruby1.8 libdbi-perl libtie-ixhash-perl libappconfig-perl libsort-naturally-perl libapache2-mod-php5"
# PostgreSQL dependencies
PKG="$PKG libdbd-pg-ruby php5-pgsql"
## RESTful API
# web
PKG="$PKG libwww-perl apache2-mpm-prefork libcgi-fast-perl"
# FastCGI dependency (optional but highly recommended)
PKG="$PKG libapache2-mod-fastcgi"

apt-get update
apt-get install -y --force-yes $PKG

# install oar frontend + server
rsync -ah /home/vagrant/oar/ /tmp/oar-src/
make -C /tmp/oar-src clean
make -C /tmp/oar-src PREFIX=/usr/local user-build tools-build
make -C /tmp/oar-src PREFIX=/usr/local user-install drawgantt-install monika-install www-conf-install api-install tools-install
make -C /tmp/oar-src PREFIX=/usr/local user-setup drawgantt-setup monika-setup www-conf-setup api-setup tools-setup
## Configure apache
a2enmod ident
a2enmod headers
a2enmod rewrite

# configure open api
perl -pi -e "s/Deny from all/#Deny from all/" /etc/oar/apache2/oar-restful-api.conf

## Configure basic auth api
echo "ScriptAlias /oarapi-priv /usr/local/lib/cgi-bin/oarapi/oarapi.cgi
ScriptAlias /oarapi-priv-debug /usr/local/lib/cgi-bin/oarapi/oarapi.cgi

<Location /oarapi-priv>
 Options ExecCGI -MultiViews FollowSymLinks
 AuthType      basic
 AuthUserfile  /etc/oar/api-users
 AuthName      \"OAR API authentication\"
 Require valid-user
 #RequestHeader set X_REMOTE_IDENT %{REMOTE_USER}e
 RewriteEngine On
 RewriteCond %{REMOTE_USER} (.*)
 RewriteRule .* - [E=MY_REMOTE_IDENT:%1]
 RequestHeader add X-REMOTE_IDENT %{MY_REMOTE_IDENT}e
</Location>
" > /etc/oar/apache2/oar-restful-api-priv.conf
ln -sf /etc/oar/apache2/oar-restful-api-priv.conf /etc/apache2/conf.d/oar-restful-api-priv.conf

htpasswd -b -c /etc/oar/api-users vagrant vagrant
htpasswd -b /etc/oar/api-users oar vagrant

## Visualization tools
sed -e "s/^\(DB_BASE_LOGIN_RO.*\)oar.*/\1oar_ro/" -i /etc/oar/drawgantt.conf
sed -e "s/^\(DB_BASE_PASSWD_RO.*\)oar.*/\1oar_ro/" -i /etc/oar/drawgantt.conf
sed -e 's/^\(username\) ?\=.*/\1 = oar_ro/' -i /etc/oar/monika.conf
sed -e 's/^\(password\) ?\=.*/\1 = oar_ro/' -i /etc/oar/monika.conf


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

echo "
************************** WELCOME TO THE OAR APPLIANCE ************************
We created 2 fake nodes pointing to localhost.
You can, for example, directly:
  $ su - vagrant
  $ oarsub -I
Or check the API:
  $ wget -O - http://localhost/oarapi/resources.yaml
Check the API more deeply, submitting a job as the \"vagrant\" user:
  $ curl -i -X POST http://vagrant:vagrant@localhost/oarapi-priv/jobs.json \\
      -H'Content-Type: application/json' \\
      -d '{\"resource\":\"/nodes=1,walltime=00:10:00\", \"command\":\"sleep 600\"}'

********************************************************************************
" >> /etc/motd.tail


# Sync .ssh keys
echo "Wait for ssh keys synchronization"
mkdir -p /var/lib/oar/.ssh/
RC=1 
while [[ RC -ne 0 ]]
do
    sleep 1
    rsync -az --partial root@server:/var/lib/oar/.ssh/authorized_keys /var/lib/oar/.ssh/authorized_keys
    RC=$?
done
rsync -az --partial root@server:/var/lib/oar/.ssh/ /var/lib/oar/.ssh/
# fix permissions
chown oar:oar -R /var/lib/oar/

service apache2 restart

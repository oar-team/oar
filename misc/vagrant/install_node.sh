#!/bin/bash
export DEBIAN_FRONTEND=noninteractive
# Package list
# dev dependencies
PKG="avahi-daemon libnss-mdns rsync"
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
# Common dependencies
PKG="$PKG perl perl-base openssh-client openssh-server"

apt-get update
apt-get install -y --force-yes $PKG

# Build oar
rsync -ah /home/vagrant/oar/ /tmp/oar-src/
make -C /tmp/oar-src/ clean
make -C /tmp/oar-src/ PREFIX=/usr/local node-build
make -C /tmp/oar-src/ PREFIX=/usr/local node-install
make -C /tmp/oar-src/ PREFIX=/usr/local node-setup

# Install initd script
cp /usr/local/share/oar/oar-node/init.d/oar-node /etc/init.d/
cp /usr/local/share/oar/oar-node/default/oar-node /etc/default/
update-rc.d oar-node defaults

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


service oar-node restart

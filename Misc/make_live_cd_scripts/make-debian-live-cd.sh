#!/bin/bash
set -e

DEFAULT_DISTRO_BASE="oar-live-cd_base.tgz"
DOWNLOAD_URL="http://oar.imag.fr/live"

usage() {
  cat <<EOF
Makes a Debian Live CD image containing provided oar packages. 
usage: $0 [-c] <packages_path> [<distro_base.tgz>]
 -c: compress the squashfs

Example workflow:
  rm -rf build-area
  ./git-build-package.sh -s deb trunk
  sudo $0 ./build-area
  sudo kvm -m 512 -boot d -cdrom /var/tmp/OAR_Debian_Live-2.4.0-1\~3.gbp842e67.iso
EOF
exit 1
}

REPOSITORY=$1
DISTRO_BASE=$2

COMPRESS=n
while getopts "sh" options; do
  case $options in
    s) COMPRESS=y ; shift;;
    *) usage ;;
  esac
done

if [ -z $REPOSITORY ]
then
  usage
fi

if [ "$USER" != "root" ]
then
  echo "This script must be run as root!"
  exit 1
else
  echo "
    Warning: this script will use a chroot to set up a system image with
    all the oar packages inside. It means that it may reload some services
    of your host. It's not dangerous, but you may have to restart apache,
    ssh, or a oar server/node already running on your host.
 
    So, don't use this script from a production host!
    You have been warned!

    Also be aware that we're going to work into /var/tmp and that we need
    about 1.5 gigas.

    Do a CTRL-C or ENTER to continue...
  "
  read nothing 
fi

if [ -z $DISTRO_BASE ]
then
  if [ -s $DEFAULT_DISTRO_BASE ]
  then
    DISTRO_BASE=$DEFAULT_DISTRO_BASE
  else
    echo "Could not find the $DEFAULT_DISTRO_BASE into the current directory"
    echo -n "Would you like me to get it from the oar web server? "
    read input
    if [ "$input" = "o" -o "$input" = "O" -o "$input" = "y" -o "$input" = "Y" ]
    then
      echo "Downloading $DOWNLOAD_URL/$DEFAULT_DISTRO_BASE ..."
      wget -q $DOWNLOAD_URL/$DEFAULT_DISTRO_BASE
      DISTRO_BASE=$DEFAULT_DISTRO_BASE
    else
      echo "Ok, you can retry and specify another distro base as a second argument."
      exit 0
    fi
  fi
fi

if [ "`which dpkg-scanpackages`" = "" ]
then
  echo "This script needs dpkg-scanpackages!"
  exit 1
fi 

if [ -d $REPOSITORY ]
then
  TMPDIR=`mktemp -p /var/tmp -d`
  if [ "`echo $TMPDIR|grep \"/var/tmp\"`" = "" ]
  then
    echo "Error creating tmp directory into /var/tmp!"
    exit 1
  fi 

  echo "**** EXTRACTING BASE $DISTRO_BASE... ****"
  tar zxf $DISTRO_BASE -C $TMPDIR
  DISTRO_DIR=$TMPDIR/oar-live-cd
  if [ -d $DISTRO_DIR/var/debs ]
  then

    echo
    echo "**** MAKING LOCAL REPOSITORY... ****"
    cp -a $REPOSITORY/* $DISTRO_DIR/var/debs
    cd $DISTRO_DIR/var
    dpkg-scanpackages debs /dev/null | gzip > debs/Packages.gz

    echo     
    echo "**** INSTALLING OAR... ****"
    echo "deb file:/var debs/" > $DISTRO_DIR/etc/apt/sources.list
    chroot $DISTRO_DIR apt-get update -q
    chroot $DISTRO_DIR bash -c "DEBIAN_FRONTEND=noninteractive apt-get -q install -y --force-yes oar-server oar-user oar-node oar-doc oar-admin oar-web-status"
    chroot $DISTRO_DIR bash -c "DEBIAN_FRONTEND=noninteractive apt-get -q install -y --force-yes oar-api" || true
    echo "deb http://ftp.fr.debian.org/debian lenny main" >> $DISTRO_DIR/etc/apt/sources.list
    echo "deb http://security.debian.org/ lenny/updates main" >> $DISTRO_DIR/etc/apt/sources.list
    echo "deb http://oar.imag.fr/debian/unstable/2.4/ ./" >> $DISTRO_DIR/etc/apt/sources.list
    echo

    echo "**** CUSTOMIZING THE SYSTEM... ****"
     # If a mysql server is already running, it will fail, so we
     # must stop it.
    RC=0
    /etc/init.d/mysql status > /dev/null || RC=$?
    if [ "$RC" = "0" ]
    then
      /etc/init.d/mysql stop
      MYSQL_STARTED=1
    fi
    # Network config
    echo "127.0.0.1 localhost oar node1 node2" > $DISTRO_DIR/etc/hosts
    echo "oar" > $DISTRO_DIR/etc/hostname
    echo "auto lo" > $DISTRO_DIR/etc/network/interfaces
    echo "iface lo inet loopback" >> $DISTRO_DIR/etc/network/interfaces
    echo "auto eth0" >> $DISTRO_DIR/etc/network/interfaces
    echo "iface eth0 inet dhcp" >> $DISTRO_DIR/etc/network/interfaces
    echo "ServerName localhost" > $DISTRO_DIR/etc/apache2/conf.d/servername
    chroot $DISTRO_DIR bash -c "a2enmod ident" 
    chroot $DISTRO_DIR bash -c "a2enmod headers" 
    chroot $DISTRO_DIR bash -c "a2enmod rewrite" 
    # Keyboard config
    cat > $DISTRO_DIR/etc/rc2.d/S99ask_keyboard <<EOS
echo "***"
echo
echo -n 'Please, give the 2 letters code of your keyboard (us, fr,...): '
read keyboard
loadkeys \$keyboard > /dev/null
echo \$keyboard > /etc/keymap
echo -n 'Start an X server? ([y]/n): '
read i
if [ "\$i" = "o" -o "\$i" = "O" -o "\$i" = "y" -o "\$i" = "Y" -o "\$i" = "" ]
then
  echo "startx" > /home/baygon/.profile
fi
EOS
    chmod 755 $DISTRO_DIR/etc/rc2.d/S99ask_keyboard
    # Path for the ruby rest client
    echo "export PATH=/var/lib/gems/1.8/bin:\$PATH" >> $DISTRO_DIR/etc/profile
    # Creation of the "baygon" user automaticaly logged in on tty1
    chroot $DISTRO_DIR bash -c "useradd -m baygon"
    perl -pi -e 's/getty.*tty1/mingetty --noclear --autologin baygon tty1/' $DISTRO_DIR/etc/inittab
    # Allow baygon to become root with "su"
    chroot $DISTRO_DIR bash -c "groupadd wheel"
    chroot $DISTRO_DIR bash -c "usermod -a -G wheel baygon"
    chroot $DISTRO_DIR bash -c "usermod -p\\\$1\\\$c0MqzZRB\\\$4DtoKo75Jy0fLm3jGlDTg0 baygon"
    echo "auth       sufficient pam_wheel.so trust" > $DISTRO_DIR/etc/pam.d/su.new
    cat $DISTRO_DIR/etc/pam.d/su >> $DISTRO_DIR/etc/pam.d/su.new
    mv $DISTRO_DIR/etc/pam.d/su $DISTRO_DIR/etc/pam.d/su.orig
    mv -f $DISTRO_DIR/etc/pam.d/su.new $DISTRO_DIR/etc/pam.d/su
    # User baygon starts a windowmaker X env at login
    echo "setxkbmap \`cat /etc/keymap\`" >> $DISTRO_DIR/home/baygon/.xinitrc
    echo "wmaker" >> $DISTRO_DIR/home/baygon/.xinitrc
    # Home configuration for baygon user
    if [ -f $DISTRO_DIR/root/home-config.tgz ]
    then
      tar zxf $DISTRO_DIR/root/home-config.tgz -C $DISTRO_DIR/home/baygon
      chroot $DISTRO_DIR bash -c "chown -R baygon /home/baygon"
      rm -f $DISTRO_DIR/home/baygon/.mozilla/*/*/sessionstore.js
    fi
    # Xorg config
    #echo "xrandr --output default --mode 1024x768" > $DISTRO_DIR/home/baygon/.xinitrc # It makes X crash... weird :-(
    perl -pi -e 's/Section "Screen"/Section "Screen"\n\tSubsection "Display"\n\t\tModes "1024x768"\n\tEndsubsection/' $DISTRO_DIR/etc/X11/xorg.conf

    echo
    echo "**** INITIALISING OAR... ****"
    # OAR key configuration
    perl -pi -e 's/^/environment="OAR_KEY=1" /' $DISTRO_DIR/var/lib/oar/.ssh/authorized_keys
    # Database init
    chroot $DISTRO_DIR bash << EOF
/etc/init.d/mysql start
/etc/init.d/oar-server stop || true
/etc/init.d/oar-node stop || true
mysql < /root/init.sql
mysql oar < /usr/lib/oar/mysql_structure.sql
mysql oar < /usr/lib/oar/mysql_default_admission_rules.sql
mysql oar < /usr/lib/oar/default_data.sql || true
oarproperty -a core
oarproperty -a cpu
oarnodesetting -a -h node1 -p cpu=0 =p core=0
oarnodesetting -a -h node1 -p cpu=0 =p core=1
oarnodesetting -a -h node1 -p cpu=1 =p core=0
oarnodesetting -a -h node1 -p cpu=1 =p core=1
oarnodesetting -a -h node2 -p cpu=0 =p core=0
oarnodesetting -a -h node2 -p cpu=0 =p core=1
oarnodesetting -a -h node2 -p cpu=1 =p core=0
oarnodesetting -a -h node2 -p cpu=1 =p core=1
sleep 2
/etc/init.d/mysql stop
EOF
    if [ "$MYSQL_STARTED" = "1" ]
    then
       /etc/init.d/mysql start
    fi

    echo
    echo "**** MAKING ISO IMAGE...****"
    rm -rf $DISTRO_DIR/tmp/*
    chroot $DISTRO_DIR /root/linux-live/build

    echo
    echo "**** MOVING ISO IMAGE...****"
    VERSION=`chroot $DISTRO_DIR dpkg -l oar-common|grep oar-common|awk '{print $3}'`
    mv -f $DISTRO_DIR/tmp/OARDebiantestimage.iso /var/tmp/OAR_Debian_Live-$VERSION.iso

    echo
    echo "**** CLEANING... ****"
    rm -rf /var/tmp/`basename $TMPDIR`

    echo 
    echo "DONE! HAVE FUN WITH:" 
    echo "**** /var/tmp/OAR_Debian_Live-$VERSION.iso ****"
    echo
    exit 0
  else
    echo "$DISTRO_DIR/var/debs not found!"
    exit 1
  fi
else
  echo "$REPOSITORY repository directory not found!"
  exit 1
fi

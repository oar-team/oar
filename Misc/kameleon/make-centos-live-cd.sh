#!/bin/bash
set -e

DEFAULT_DISTRO_BASE="/var/guest/centos-oar-base-image.tgz"
DOWNLOAD_URL="http://oar.imag.fr/live"
#KERNEL=ftp://ftp.slax.org/Linux-Live/kernels/2.6.27.7/linux-2.6.27.7-i486-1.tgz
KERNEL=$DOWNLOAD_URL/linux-2.6.27.7-i486-1.tgz

usage() {
  cat <<EOF
Makes a Centos Live CD image containing provided oar packages. 
usage: $0 [-c] <packages_path> [<distro_base.tgz>]
 -c: compress the squashfs

Example workflow:
  rm -rf build-area
  ./git-build-package.sh -s rpm trunk-work
  sudo $0 ./build-area/rpm/RPMS
  sudo kvm -m 512 -boot d -cdrom /var/tmp/OAR_RPM_Live-2.4.0-1\~3.gbp842e67.iso
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

if [ "`which createrepo`" = "" ]
then
  echo "This script needs createrepo!"
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
  if [ -d $DISTRO_DIR/var/rpms ]
  then

    echo
    echo "**** MAKING LOCAL REPOSITORY... ****"
    cp -a $REPOSITORY/* $DISTRO_DIR/var/rpms
    cd $DISTRO_DIR/var/rpms
    createrepo .
    cd ../../..

    echo 
    echo "**** Mounting /proc, creating devices and init ssh...****"
    chroot $DISTRO_DIR bash -c "mount -t proc none /proc"
    chroot $DISTRO_DIR bash -c "MAKEDEV /dev"
    chroot $DISTRO_DIR bash -c "/etc/init.d/sshd start; /etc/init.d/sshd stop >/dev/null 2>&1"

    echo 
    echo "**** Configuring yum...****"
    # Configuring yum for oar local repository
    echo "[oar-local-repo]
name=OAR-LOCAL-REPO
baseurl=file:///var/rpms
gpgcheck=0
enabled=1" > $DISTRO_DIR/etc/yum.repos.d/oar.repo
    # Configuring yum for extra packages from rpmforge
    echo "[rpmforge]
name = Red Hat Enterprise $releasever - RPMforge.net - dag
#baseurl = http://apt.sw.be/redhat/el5/en/$basearch/dag
mirrorlist = http://apt.sw.be/redhat/el5/en/mirrors-rpmforge
#mirrorlist = file:///etc/yum.repos.d/mirrors-rpmforge
enabled = 1
protect = 0
gpgkey = file:///etc/pki/rpm-gpg/RPM-GPG-KEY-rpmforge-dag
gpgcheck = 0" > $DISTRO_DIR/etc/yum.repos.d/rpmforge.repo
    # Configuring yum for OAR online repository
    echo "[oar]
name=OAR
baseurl=http://oar.imag.fr/RPMS/unstable/2.4
gpgcheck=0
enabled=1" >> $DISTRO_DIR/etc/yum.repos.d/oar.repo

    echo 
    echo "**** Downloading kernel...****"
    wget -q -c $KERNEL
    echo 
    echo "**** Installing kernel...****"
    #chroot $DISTRO_DIR bash -c "yum install -q -y kernel"
    tar zxf `basename $KERNEL` -C $DISTRO_DIR

    echo     
    echo "**** INSTALLING OAR... ****"
    # Installing oar packages
    chroot $DISTRO_DIR bash -c "yum install -q -y oar-server oar-user oar-node oar-doc oar-admin oar-web-status"
    chroot $DISTRO_DIR bash -c "yum install -q -y oar-api" || true
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
    chroot $DISTRO_DIR yum clean all
    umount $DISTRO_DIR/proc
    rm -rf $DISTRO_DIR/tmp/*
    #chroot $DISTRO_DIR bash -c "cd /boot && ln -s vmlinuz-* ./vmlinuz"
    #chroot $DISTRO_DIR bash -c "cd /boot && ln -s initrd-* ./initrd"
    #K_VERSION=`chroot $DISTRO_DIR bash -c "rpm -q kernel --qf '%{VERSION}-%{RELEASE}'"`
    K_VERSION=`/bin/ls $DISTRO_DIR/lib/modules|sort -n|tail -1`
    perl -pi -e "s/^KERNEL=.*/KERNEL=$K_VERSION/" $DISTRO_DIR/root/linux-live/.config
    chroot $DISTRO_DIR depmod -a $K_VERSION
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

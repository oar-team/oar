#!/bin/bash
# $Id: rpmbuilder.sh,v 1.5 2004/12/15 10:06:22 neyron Exp $

[ -n "$RPM_HOME" ] || RPM_HOME=/usr/src/RPM

[ ! -w $RPM_HOME ] && echo "RPM_HOME ($RPM_HOME) not writable" && exit 1

[ $EUID -ne 0 ] && ! FAKEROOT=`which fakeroot` && echo "You need either to be root or to have fakeroot available" && exit 1

[ ! -r rpm/oar.spec ] && echo "Could not find oar.spec, this script is to be invoked as rpm/$0 from OAR source directory" && exit 1

[ ! -r Tools/oarversion.pm ]  && echo "Counld not find oarversion.pm, this script is to be invoked as rpm/$0 from OAR source directory" && exit 1

_VERSION=`perl -I Tools -e 'use oarversion;print oarversion::get_version;'`
_RELEASE=1

read -p "OAR version [$_VERSION]?" VERSION
[ -z $VERSION ] && VERSION=$_VERSION

read -p "Package release number [$_RELEASE]?" RELEASE
[ -z $RELEASE ] && RELEASE=$_RELEASE

echo "Package names will be oar-{common|server|user|node|draw-gantt|desktop-computing-cgi|desktop-computing-agent|doc}-$VERSION-$RELEASE.rpm."
read -p "Continue [Y/n]?" CONTINUE 
[ "x$CONTINUE" = "xn" -o "x$CONTINUE" = "xN" ] && echo "Aborted" && exit 1


perl -pe "s#^%define version.*#%define version $VERSION#; s#^%define release.*#%define release $RELEASE#" rpm/oar.spec > $RPM_HOME/SPECS/oar.spec

mkdir -p /tmp/oar-$VERSION
cp -a * /tmp/oar-$VERSION
tar cfj $RPM_HOME/SOURCES/oar-$VERSION.tar.bz2 -C /tmp oar-$VERSION

$FAKEROOT rpm -ba $RPM_HOME/SPECS/oar.spec

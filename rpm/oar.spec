# $Id$
%define version 1.6
%define release 1
	
Summary:	OAR Batch Scheduler
Name:		oar
Version:	%{version}
Release:	%{release}
License:	GPL
Group:		System/Servers
Url:		http://oar.imag.fr


Source0:	oar_%{version}.tar.gz
BuildRoot:	%{_tmppath}/oar-%{version}-%{release}-build
BuildRequires:	perl sed make tar
Prereq:		/sbin/chkconfig /sbin/service rpm-helper
Requires:	/bin/sh

%description 
This is OAR Batch Scheduler

%package common
Summary:	OAR batch scheduler common package
Group:		System/Servers
BuildArch: noarch
Requires:	sudo, perl, perl-Mysql
provides: perl(oar_iolib)

%description common
This package installs the server part or the OAR batch scheduler

%package server
Summary:	OAR batch scheduler server package
Group:		System/Servers
Requires:	oar-common = %version-%release
BuildArch: noarch

%description server
This package installs the server part or the OAR batch scheduler

%package user
Summary:	OAR batch scheduler node package
Group:		System/Servers
Requires:	oar-common = %version-%release
BuildArch: noarch

%description user
This package install the submition and query part or the OAR batch scheduler

%package node
Summary:	OAR batch scheduler node package
Group:		System/Servers
Requires:	oar-common = %version-%release
BuildArch: noarch

%description node
This package installs the execution node part or the OAR batch scheduler

%package draw-gantt
Summary:	OAR batch scheduler Gantt reservation diagram
Group:		System/Servers
Requires:	oar-common = %version-%release, oar-user = %version-%release, monika, 
BuildArch: noarch

%description draw-gantt
This package install the OAR batch scheduler Gantt reservation diagram CGI

%package desktop-computing-cgi
Summary:	OAR batch scheduler desktop computing CGI
Group:		System/Servers
Requires:	oar-common = %version-%release
BuildArch: noarch

%description desktop-computing-cgi
This package install the OAR batch scheduler desktop computing CGI

%package desktop-computing-agent
Summary:	OAR batch scheduler desktop computing Agent
Group:		System/Servers
Requires:	oar-common = %version-%release
BuildArch: noarch

%description desktop-computing-agent
This package install the OAR batch scheduler desktop computing Agent

%package doc
Summary:	OAR batch scheduler documentation package
Group:		Documentation/Other
BuildArch: noarch

%description doc
This package install some documentation for OAR batch scheduler



%prep
%setup -n oar

%build
# Dumb install needed to create file lists
mkdir -p tmp
# Install oar-doc
mkdir -p tmp/oar-doc
make doc \
PREFIX=`pwd`/tmp/oar-doc/usr \
DOCDIR=`pwd`/tmp/oar-doc/usr/share/doc/oar
( cd tmp/oar-doc && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-doc.files
rm -rf tmp/oar-doc
# Install oar-common
mkdir -p tmp/oar-common/var/lib/oar
make sanity-check common configuration \
OARUSER=oar \
OARHOMEDIR=`pwd`/tmp/oar-common/var/lib/oar \
OARCONFDIR=`pwd`/tmp/oar-common/etc \
PREFIX=`pwd`/tmp/oar-common/usr \
MANDIR=`pwd`/tmp/oar-common/usr/share/man \
OARDIR=`pwd`/tmp/oar-common/usr/lib/oar \
BINDIR=`pwd`/tmp/oar-common/usr/bin \
SBINDIR=`pwd`/tmp/oar-common/usr/sbin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
( cd tmp/oar-common && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-common.files
rm -rf tmp/oar-common
# Install oar-server
mkdir -p tmp/oar-server/var/lib/oar
make sanity-check server dbinit \
OARUSER=oar \
OARHOMEDIR=`pwd`/tmp/oar-server/var/lib/oar \
OARCONFDIR=`pwd`/tmp/oar-server/etc \
PREFIX=`pwd`/tmp/oar-server/usr \
MANDIR=`pwd`/tmp/oar-server/usr/share/man \
OARDIR=`pwd`/tmp/oar-server/usr/lib/oar \
BINDIR=`pwd`/tmp/oar-server/usr/bin \
SBINDIR=`pwd`/tmp/oar-server/usr/sbin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
( cd tmp/oar-server && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-server.files
rm -rf tmp/oar-server
# Install oar-node
mkdir -p tmp/oar-node/var/lib/oar
make sanity-check node \
OARUSER=oar \
OARHOMEDIR=`pwd`/tmp/oar-node/var/lib/oar \
OARCONFDIR=`pwd`/tmp/oar-node/etc \
PREFIX=`pwd`/tmp/oar-node/usr \
MANDIR=`pwd`/tmp/oar-node/usr/share/man \
OARDIR=`pwd`/tmp/oar-node/usr/lib/oar \
BINDIR=`pwd`/tmp/oar-node/usr/bin \
SBINDIR=`pwd`/tmp/oar-node/usr/sbin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
( cd tmp/oar-node && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-node.files
rm -rf tmp/oar-node
# Install oar-user
mkdir -p tmp/oar-user/var/lib/oar
make sanity-check user \
OARUSER=oar \
OARHOMEDIR=`pwd`/tmp/oar-user/var/lib/oar \
OARCONFDIR=`pwd`/tmp/oar-user/etc \
PREFIX=`pwd`/tmp/oar-user/usr \
MANDIR=`pwd`/tmp/oar-user/usr/share/man \
OARDIR=`pwd`/tmp/oar-user/usr/lib/oar \
BINDIR=`pwd`/tmp/oar-user/usr/bin \
SBINDIR=`pwd`/tmp/oar-user/usr/sbin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
( cd tmp/oar-user && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-user.files
rm -rf tmp/oar-user
# Install oar-draw-gantt
mkdir -p tmp/oar-draw-gantt/var/www/cgi-bin
make draw-gantt \
OARUSER=oar \
OARHOMEDIR=`pwd`/tmp/oar-draw-gantt/var/lib/oar \
OARCONFDIR=`pwd`/tmp/oar-draw-gantt/etc \
PREFIX=`pwd`/tmp/oar-draw-gantt/usr \
MANDIR=`pwd`/tmp/oar-draw-gantt/usr/share/man \
OARDIR=`pwd`/tmp/oar-draw-gantt/usr/lib/oar \
BINDIR=`pwd`/tmp/oar-draw-gantt/usr/bin \
SBINDIR=`pwd`/tmp/oar-draw-gantt/usr/sbin \
WWWDIR=`pwd`/tmp/oar-draw-gantt/var/www/html \
CGIDIR=`pwd`/tmp/oar-draw-gantt/var/www/cgi-bin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
( cd tmp/oar-draw-gantt && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-draw-gantt.files
rm -rf tmp/oar-draw-gantt
# Install oar-desktop-computing-cgi
mkdir -p tmp/oar-desktop-computing-cgi/var/www/cgi-bin
make desktop-computing-cgi \
OARUSER=oar \
OARHOMEDIR=`pwd`/tmp/oar-desktop-computing-cgi/var/lib/oar \
OARCONFDIR=`pwd`/tmp/oar-desktop-computing-cgi/etc \
PREFIX=`pwd`/tmp/oar-desktop-computing-cgi/usr \
MANDIR=`pwd`/tmp/oar-desktop-computing-cgi/usr/share/man \
OARDIR=`pwd`/tmp/oar-desktop-computing-cgi/usr/lib/oar \
BINDIR=`pwd`/tmp/oar-desktop-computing-cgi/usr/bin \
SBINDIR=`pwd`/tmp/oar-desktop-computing-cgi/usr/sbin \
WWWDIR=`pwd`/tmp/oar-desktop-computing-cgi/var/www/html \
CGIDIR=`pwd`/tmp/oar-desktop-computing-cgi/var/www/cgi-bin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
( cd tmp/oar-desktop-computing-cgi && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-desktop-computing-cgi.files
rm -rf tmp/oar-desktop-computing-cgi
# Install oar-desktop-computing-agent
mkdir -p tmp/oar-desktop-computing-agent/var/www/cgi-bin
make desktop-computing-agent \
OARUSER=oar \
OARHOMEDIR=`pwd`/tmp/oar-desktop-computing-agent/var/lib/oar \
OARCONFDIR=`pwd`/tmp/oar-desktop-computing-agent/etc \
PREFIX=`pwd`/tmp/oar-desktop-computing-agent/usr \
MANDIR=`pwd`/tmp/oar-desktop-computing-agent/usr/share/man \
OARDIR=`pwd`/tmp/oar-desktop-computing-agent/usr/lib/oar \
BINDIR=`pwd`/tmp/oar-desktop-computing-agent/usr/bin \
SBINDIR=`pwd`/tmp/oar-desktop-computing-agent/usr/sbin \
WWWDIR=`pwd`/tmp/oar-desktop-computing-agent/var/www/html \
CGIDIR=`pwd`/tmp/oar-desktop-computing-agent/var/www/cgi-bin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
( cd tmp/oar-desktop-computing-agent && ( find -type f && find -type l ) | sed 's#^.##' ) > oar-desktop-computing-agent.files
rm -rf tmp/oar-desktop-computing-agent
rm -rf tmp
perl -i -pe '
	s#^(/etc/oar.conf.*)#%config %attr(0600,oar,root) $1#; 
	s#^(/usr/share/doc.*)#%doc $1#; 
	s#^(/usr/share/man.*)#$1*#;
	' oar-*.files

%install
# install everything but oar-drawgantt
mkdir -p $RPM_BUILD_ROOT/var/lib/oar
make sanity-check common configuration server dbinit user node doc draw-gantt desktop-computing-cgi desktop-computing-agent \
OARUSER=oar \
OARHOMEDIR=$RPM_BUILD_ROOT/var/lib/oar \
OARCONFDIR=$RPM_BUILD_ROOT/etc \
PREFIX=$RPM_BUILD_ROOT/usr \
DOCDIR=$RPM_BUILD_ROOT/usr/share/doc/oar \
MANDIR=$RPM_BUILD_ROOT/usr/share/man \
OARDIR=$RPM_BUILD_ROOT/usr/lib/oar \
BINDIR=$RPM_BUILD_ROOT/usr/bin \
SBINDIR=$RPM_BUILD_ROOT/usr/sbin \
WWWDIR=$RPM_BUILD_ROOT/var/www/html \
CGIDIR=$RPM_BUILD_ROOT/var/www/cgi-bin \
BINLINKPATH=../lib/oar \
SBINLINKPATH=../lib/oar
perl -i -pe 's#^OARDIR=.*#OARDIR=/usr/lib/oar#' $RPM_BUILD_ROOT/usr/lib/oar/sudowrapper.sh
perl -i -pe 's#^(path_cache_directory\s*=\s*).*#$1/var/www/html/DrawGantt/cache#' $RPM_BUILD_ROOT/usr/lib/oar/sudowrapper.sh
# install oar-server service extra files
cp rpm/oar-server $RPM_BUILD_ROOT/usr/sbin/oar-server
mkdir -p $RPM_BUILD_ROOT/etc/init.d
cp rpm/oar-server.init.d $RPM_BUILD_ROOT/etc/init.d/oar-server

%clean
rm -rf $RPM_BUILD_ROOT

%files common -f oar-common.files

%pre common
groupadd oar &> /dev/null || true
useradd -d /var/lib/oar -g oar oar &> /dev/null || true
chown oar.oar /var/lib/oar -R &> /dev/null
if [ -e /etc/oar.conf ]; then
	chown oar.root /etc/oar.conf &> /dev/null 
	chmod 600 /etc/oar.conf &> /dev/null
fi
touch /var/log/oar.log && chown oar /var/log/oar.log && chmod 644 /var/log/oar.log || true
if [ ! -e /etc/sudoers ]; then
	echo "Error: No /etc/sudoers file. Is sudo installed ?" 
	exit 1
fi
perl -e '
use Fcntl;
my $sudoers = "/etc/sudoers";
my $sudoerstmp = "/etc/sudoers.tmp";
my $oar_tag="# DO NOT REMOVE, needed by OAR packages";
my $struct=pack("ssll", F_WRLCK, SEEK_CUR, 0, 0);
sysopen (SUDOERS, $sudoers, O_RDWR|O_CREAT, 0440) or die "sysopen $sudoers: $!";
fcntl(SUDOERS, F_SETLK, $struct) or die "fcntl: $!";
sysopen (SUDOERSTMP, "$sudoerstmp", O_RDWR|O_CREAT, 0440) or die "sysopen $sudoerstmp: $!";
print SUDOERSTMP grep (!/$oar_tag/, <SUDOERS>);
print SUDOERSTMP <<EOF;
##BEGIN$oar_tag
Cmnd_Alias OARCMD = /usr/lib/oar/oarnodes, /usr/lib/oar/oarstat, /usr/lib/oar/oarsub, /usr/lib/oar/oardel, /usr/lib/oar/oarhold, /usr/lib/oar/oarnotify, /usr/lib/oar/oarresume, /usr/lib/oar/oar-cgi, /usr/lib/oar/oarfetch $oar_tag
%oar ALL=(oar) NOPASSWD: OARCMD $oar_tag
oar ALL=(ALL)   NOPASSWD: ALL $oar_tag
##END$oar_tag
EOF
close SUDOERSTMP or die "close $sudoerstmp: $!";
rename "/etc/sudoers.tmp", "/etc/sudoers" or die "rename: $!";
close SUDOERS or die "close $sudoers: $!";
'

%post common

%preun common
if [ ! -e /etc/sudoers ]; then
	echo "Error: No /etc/sudoers file. Is sudo installed ?" 
	exit 1
fi
perl -e '
use Fcntl;
my $sudoers = "/etc/sudoers";
my $sudoerstmp = "/etc/sudoers.tmp";
my $oar_tag="# DO NOT REMOVE, needed by OAR package";
my $struct=pack("ssll", F_WRLCK, SEEK_CUR, 0, 0);
sysopen (SUDOERS, $sudoers, O_RDWR|O_CREAT, 0440) or die "sysopen $sudoers: $!";
fcntl(SUDOERS, F_SETLK, $struct) or die "fcntl: $!";
sysopen (SUDOERSTMP, "$sudoerstmp", O_RDWR|O_CREAT, 0440) or die "sysopen $sudoerstmp: $!";
print SUDOERSTMP grep (!/$oar_tag/, <SUDOERS>);
close SUDOERSTMP or die "close $sudoerstmp: $!";
rename "/etc/sudoers.tmp", "/etc/sudoers" or die "rename: $!";
close SUDOERS or die "close $sudoers: $!";
'
userdel oar &> /dev/null || true
groupdel oar &> /dev/null || true
rm -rf /var/log/oar.log || true

%postun common

%pre server

%post server
if [ ! -e /var/lib/oar/.ssh/id_dsa -o \
	! -e /var/lib/oar/.ssh/id_dsa.pub -o \
	! -e /var/lib/oar/.ssh/authorized_keys ]; then
	mkdir -p /var/lib/oar/.ssh 
	ssh-keygen -t dsa -q -f /var/lib/oar/.ssh/id_dsa -N '' || true
	cp /var/lib/oar/.ssh/id_dsa.pub /var/lib/oar/.ssh/authorized_keys || true
fi
cat <<EOF > /var/lib/oar/.ssh/config || true
	Host *
	ForwardX11 no 
	StrictHostKeyChecking no
EOF
chown oar.oar /var/lib/oar/.ssh -R || true
chkconfig --add oar-server

%preun server
service oar-server stop || true
chkconfig --del oar-server

%post draw-gantt
usermod -G "`id -Gn apache | sed 's/ /,/g'`,oar" apache || true
mkdir -p /var/www/html/DrawGantt/cache && chown apache /var/www/DrawGantt/cache || true

%preun draw-gantt
usermod -G "`id -Gn apache | sed 's/oar//;s/^ //;s/ $//;s/ \+/,/g'`" apache || true
rm -rf /var/www/DrawGantt/cache || true

%post desktop-computing-cgi
usermod -G "`id -Gn apache | sed 's/ /,/g'`,oar" apache || true
ln -sf /usr/sbin/oarcache /etc/cron.hourly/oarcache

%preun desktop-computing-cgi
usermod -G "`id -Gn apache | sed 's/oar//;s/^ //;s/ $//;s/ \+/,/g'`" apache || true
rm -f /etc/cron.hourly/oarcache

%files server -f oar-server.files
/usr/sbin/oar-server
/etc/init.d/oar-server

%files user -f oar-user.files

%files node -f oar-node.files

%files draw-gantt -f oar-draw-gantt.files

%files desktop-computing-cgi -f oar-desktop-computing-cgi.files

%files desktop-computing-agent -f oar-desktop-computing-agent.files

%files doc -f oar-doc.files

%changelog
* Tue May 10 2005 Pierre Lombard <pl@icatis.com> 1.6-1
- New upstream version.
* Wed Feb 04 2005 Sebastien Georget <sebastien.georget@sophia.inria.fr> 1.4-1
- Update dependencies, change Source0 and %setup to use default oar distribution
* Wed Jun 30 2004 Pierre Neyron <pierre.neyron@imag.fr> 1.0-1
- First RPM package

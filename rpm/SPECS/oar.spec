# $Id: oar.spec 1761 2008-11-28 14:48:25Z bzizou $
%define version 2.4.0
%define release 5

Name: 		oar
Version:        %{version}
Release:        %{release}
Summary: 	OAR batch scheduler
License: 	GPL
Group: 		System/Servers
Url:            http://oar.imag.fr

%define _topdir %(pwd)
# %define _rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm
# %define _unpackaged_files_terminate_build 0

Source0: 	oar-%version.tar.gz
Source1:	Makefile.install
Source2:	oar-common.logrotate
Source3:	oar-server.init.d
Source4:	oar-server.cron.d
Source5:	oar-server
Source6:	oar-node.init.d
Source7:	oar-node.cron.d
Source8:	oar-node.sysconfig
Source9:	oar-server.sysconfig
BuildRoot:      %{_tmppath}/oar-%{version}-%{release}-build
#BuildRequires:  perl sed make tar xauth
BuildArch: 	noarch
%description
OAR is a resource manager (or batch scheduler) for large computing clusters.

%package common
Summary:        OAR batch scheduler common package
Group:          System/Servers
BuildArch: 	noarch
Requires:       perl, perl-suidperl, shadow-utils, perl-DBI
  # How could we do (libdbd-mysql-perl | libdbd-pg-perl) ?
Provides: 	perl(oar_iolib), perl(oar_Judas), perl(oar_Tools), perl(oar_conflib), perl(oar_resource_tree), perl(oarversion), perl(oarstat_lib), perl(oarnodes_lib), perl(oarsub_lib), perl(oar_apilib)
%description common
This package installs the common part or the OAR batch scheduler

%package server
Summary:        OAR batch scheduler server package
Group:          System/Servers
Requires:       oar-common = %version-%release, openssh-clients, openssh-server, vixie-cron
BuildArch: 	noarch
%description server
This package installs the server part or the OAR batch scheduler

%package node
Summary:	OAR batch scheduler node package
Group:          System/Servers
Requires:       oar-common = %version-%release, openssh-clients, openssh-server
BuildArch: 	noarch
%description node
This package installs the execution node part of the OAR batch scheduler

%package user
Summary:	OAR batch scheduler user package
Group:          System/Servers
Requires:       oar-common = %version-%release, openssh-clients
BuildArch: 	noarch
%description user
This package install the submission and query part of the OAR batch scheduler

%package web-status
Summary:	OAR batch scheduler web-status package
Group:          System/Servers
Requires:       ruby, perl-DBI, perl-Tie-IxHash, perl-AppConfig, ruby-DBI, ruby-GD, perl(Sort::Naturally), httpd
 # Some Ruby dependencies missing (libdbd-mysql-ruby|libdbd-pg-ruby)
BuildArch: 	noarch
Provides:       Monika, DrawGantt
%description web-status
This package installs the OAR batch scheduler Gantt reservation diagram CGI: DrawGantt and the instant cluster state visualization CGI: Monika

%package doc
Summary:	OAR batch scheduler doc package
Group:          System/Servers
Requires:       man, httpd
BuildArch: 	noarch
#BuildRequires:  python-docutils, httpd
%description doc
This package installs some documentation for OAR batch scheduler

%package admin
Summary:	OAR batch scheduler administration tools package
Group:          System/Servers
Requires:       oar-common = %version-%release, ruby, ruby-DBI, perl(YAML)
BuildArch: 	noarch
%description admin
This package installs some useful tools to help the administrator of a oar server (resources manipulation, admission rules edition, ...) 

%package desktop-computing-agent
Summary:        OAR desktop computing agent
Group:          System/Servers
Requires:	perl-libwww-perl, perl-URI
BuildArch:	noarch
%description desktop-computing-agent
This package install the OAR batch scheduler desktop computing agent

%package desktop-computing-cgi
Summary:	OAR desktop computing HTTP proxy CGI
Group:          System/Servers
Requires:	perl(CGI), oar-common = %version-%release, httpd
BuildArch:      noarch
%description    desktop-computing-cgi	
This package install the OAR batch scheduler desktop computing HTTP proxy CGI

%package api
Summary:	OAR RESTful user API
Group:          System/Servers
Requires:	perl(CGI), oar-common >= 2.4.0-1, oar-user >= 2.4.0-1, httpd
BuildArch:      noarch
%description    api
This package installs the RESTful OAR user API.

%package gridapi
Summary:	OARGRID RESTful user API
Group:          System/Servers
Requires:	perl(CGI), oar-common >= 2.4.0-1, oar-user >= 2.4.0-1, httpd, oar-api = %version-%release
BuildArch:      noarch
%description    gridapi
This package installs the RESTful OARGRID user API.

%prep
%setup -T -b 0
cp %{_topdir}/SOURCES/Makefile.install .

# Modify Makefile for chown commands to be non-fatal as the permissions
# are set by the packaging
perl -i -pe "s/chown/-chown/" Makefile
perl -i -pe "s/-o root//" Makefile
perl -i -pe "s/-g root//" Makefile

%build
# Install into separated directories using the provided makefile
make -f Makefile.install pkginstall BUILDDIR=tmp WWWUSER=$USER DESTDIR=$RPM_BUILD_ROOT 
# Reconstruct the whole system
mkdir -p $RPM_BUILD_ROOT
cp -a tmp/*/* $RPM_BUILD_ROOT/
# Get the file lists for every package (except those explicitely listed later)
EXCEPTS="oar.conf\$|oarsh_oardo\$|bin/oarnodesetting\$|oar/job_resource_manager.pl\$\
|oar/oardodo/oardodo\$|oarmonitor_sensor.pl\$|server_epilogue\$|server_prologue\$\
|suspend_resume_manager.pl\$|bin/oarnotify\$|bin/oarremoveresource\$|bin/oaraccounting\$\
|bin/Almighty\$|bin/oarnotify\$|bin/oarremoveresource\$|bin/oaraccounting\$\
|bin/oarproperty\$|bin/oarmonitor\$|drawgantt.conf\$|monika.conf\$|oar/epilogue\$\
|oar/prologue\$|oar/sshd_config\$|bin/oarnodes\$|bin/oardel\$|bin/oarstat\$\
|bin/oarsub\$|bin/oarhold\$|bin/oarresume\$|sbin/oaradmin\$\
|sbin/oarcache\$|sbin/oarres\$|oar/oarres\$|bin/oar-cgi\$|apache.conf\$|bin/oar_resources_init"
for package in oar-common oar-server oar-node oar-user oar-web-status oar-doc oar-admin oar-desktop-computing-agent oar-desktop-computing-cgi oar-api oar-gridapi
do
  ( cd tmp/$package && ( find -type f && find -type l ) | sed 's#^.##' ) \
    | egrep -v "$EXCEPTS" > $package.files
done
# Additional distribution dependent files
install -D -m 755 %{_topdir}/SOURCES/oar-common.logrotate $RPM_BUILD_ROOT/etc/logrotate.d/oar
install -D -m 755 %{_topdir}/SOURCES/oar-server.init.d $RPM_BUILD_ROOT/etc/init.d/oar-server
install -D -m 755 %{_topdir}/SOURCES/oar-node.init.d $RPM_BUILD_ROOT/etc/init.d/oar-node
install -D -m 755 %{_topdir}/SOURCES/oar-server $RPM_BUILD_ROOT/usr/sbin/oar-server
install -D -m 755 %{_topdir}/SOURCES/oar-server.cron.d $RPM_BUILD_ROOT/etc/cron.d/oar-server
install -D -m 755 %{_topdir}/SOURCES/oar-node.cron.d $RPM_BUILD_ROOT/etc/cron.d/oar-node
install -D -m 755 %{_topdir}/SOURCES/oar-node.sysconfig $RPM_BUILD_ROOT/etc/sysconfig/oar-node
install -D -m 755 %{_topdir}/SOURCES/oar-server.sysconfig $RPM_BUILD_ROOT/etc/sysconfig/oar-server
install -D -m 644 %{_topdir}/SOURCES/oar-node.sshd_config $RPM_BUILD_ROOT/etc/oar/sshd_config
install -D -m 644 %{_topdir}/SOURCES/apache.conf $RPM_BUILD_ROOT/etc/oar/apache.conf
install -D -m 644 %{_topdir}/SOURCES/apache-api.conf $RPM_BUILD_ROOT/etc/oar/apache-api.conf
install -D -m 644 %{_topdir}/SOURCES/apache2-grid.conf $RPM_BUILD_ROOT/etc/oar/apache-gridapi.conf
install -D -m 644 %{_topdir}/SOURCES/oar-desktop-computing-cgi.cron.hourly $RPM_BUILD_ROOT/etc/cron.hourly/oar-desktop-computing-cgi
mkdir -p $RPM_BUILD_ROOT/var/lib/oar/checklogs

%clean
rm -rf $RPM_BUILD_ROOT/*
rm -rf tmp


###### files and permissions ######

%files common -f oar-common.files
%config %attr(0600,oar,root) /etc/oar/oar.conf 
%config %attr(0755,root,root) /etc/logrotate.d/oar
%attr(6755,oar,oar) /usr/lib/oar/oarsh_oardo
%attr(6750,root,oar) /usr/lib/oar/oardodo/oardodo
%attr(6750,oar,oar) /usr/sbin/oarnodesetting

%files server -f oar-server.files
%attr(0755,root,root) /etc/init.d/oar-server
%config /etc/oar/job_resource_manager.pl
%config /etc/oar/oarmonitor_sensor.pl
%config /etc/oar/server_epilogue
%config /etc/oar/server_prologue
%config /etc/oar/suspend_resume_manager.pl
%config %attr(0644,root,root) /etc/cron.d/oar-server
%attr (6750,oar,oar) /usr/sbin/Almighty
%attr (6750,oar,oar) /usr/sbin/oarnotify
%attr (6750,oar,oar) /usr/sbin/oarremoveresource
%attr (6750,oar,oar) /usr/sbin/oaraccounting
%attr (6750,oar,oar) /usr/sbin/oarproperty
%attr (6750,oar,oar) /usr/sbin/oarmonitor
%attr (0750,oar,oar) /usr/sbin/oar-server
%attr (6750,oar,oar) /usr/sbin/oar_resources_init
%config /etc/sysconfig/oar-server

%files node -f oar-node.files
%attr(0755,root,root) /etc/init.d/oar-node
%config /etc/oar/epilogue
%config /etc/oar/prologue
%config /etc/oar/sshd_config
%config /etc/oar/check.d
%config %attr(0644,root,root) /etc/cron.d/oar-node
%config /var/lib/oar/checklogs
%config /etc/sysconfig/oar-node

%files user -f oar-user.files
%attr (6755,oar,oar) /usr/bin/oarnodes
%attr (6755,oar,oar) /usr/bin/oarnodes.old
%attr (6755,oar,oar) /usr/bin/oardel
%attr (6755,oar,oar) /usr/bin/oarstat
%attr (6755,oar,oar) /usr/bin/oarstat.old
%attr (6755,oar,oar) /usr/bin/oarsub
%attr (6755,oar,oar) /usr/bin/oarhold
%attr (6755,oar,oar) /usr/bin/oarresume

%files web-status -f oar-web-status.files
%config %attr (0600,apache,root) /etc/oar/drawgantt.conf
%config %attr (0600,apache,root) /etc/oar/monika.conf
%config %attr (0600,apache,root) /etc/oar/apache.conf

%files doc -f oar-doc.files
%docdir /usr/share/doc/oar-doc 

%files admin -f oar-admin.files
%attr(6750,oar,oar) /usr/sbin/oaradmin

%files desktop-computing-agent -f oar-desktop-computing-agent.files

%files desktop-computing-cgi -f oar-desktop-computing-cgi.files
%config %attr (0755,root,root) /etc/cron.hourly/oar-desktop-computing-cgi
%attr(6750,oar,oar) /usr/sbin/oarcache
%attr(6750,oar,oar) /usr/lib/oar/oarres
%attr(6750,oar,apache) /var/www/cgi-bin/oar-cgi

%files api -f oar-api.files
%config %attr (0600,apache,root) /etc/oar/apache-api.conf
%config %attr (0640,oar,apache) /etc/oar/api_html_header.pl
%config %attr (0640,oar,apache) /etc/oar/api_html_postform.pl
%attr(0750,oar,apache) /var/www/cgi-bin/oarapi
%attr(6755,oar,oar) /var/www/cgi-bin/oarapi/oarapi.cgi
%attr(6755,oar,oar) /var/www/cgi-bin/oarapi/oarapi-debug.cgi

%files gridapi -f oar-gridapi.files
%config %attr (0600,apache,root) /etc/oar/apache-gridapi.conf
%config %attr (0640,oar,apache) /etc/oar/gridapi_html_header.pl
%config %attr (0640,oar,apache) /etc/oar/gridapi_html_postform.pl
%attr(6755,oar,oar) /var/www/cgi-bin/oarapi/oargridapi.cgi
%attr(6755,oar,oar) /var/www/cgi-bin/oarapi/oargridapi-debug.cgi

###### oar-common scripts ######

%pre common
# Set up the oar user
if ! getent group oar > /dev/null 2>&1 ; then
    groupadd -r oar
fi
if ! getent passwd oar > /dev/null 2>&1 ; then
    mkdir -p /var/lib/oar
    useradd -r -m -d /var/lib/oar -g oar -s /bin/bash oar
    usermod -U oar
    cd /var/lib/oar
    echo '' >> .bash_profile
    echo 'export PATH="/usr/lib/oar/oardodo:$PATH"' >> .bash_profile
    chown oar:oar /var/lib/oar/.bash_profile
    ln -s -f .bash_profile .bashrc
    chown oar:oar .bashrc
fi
chown oar:oar /var/lib/oar -R > /dev/null 2>&1
# Create log and status files
touch /var/log/oar.log && chown oar:root /var/log/oar.log && chmod 0644 /var/log/oar.log || true
install -o oar -m 755 -d /var/run/oar

%post common
# set OAR Shell
chsh -s /usr/lib/oar/oarsh_shell oar
if [ "$1" != "1" ]
then
  echo
  echo "WARNING! If you upgraded from 2.3.4 or earlier, you have to upgrade the"
  echo "database scheme (stop OAR before)!"
  echo " Upgrade SQL scripts are available in the /usr/lib/oar/db_upgrade directory"
  echo
fi

%postun common
if [ "$1" = 0 ];
then
  userdel oar &> /dev/null || true
  groupdel oar &> /dev/null || true
  rm -f /var/log/oar.log* || true
  rm -rf /var/run/oar || true
fi

###### oar-server scripts ######

%post server
# Set up ssh configuration
if [ -e /var/lib/oar/.ssh ]; then
    # Do nothing
    :
else
    mkdir -p /var/lib/oar/.ssh
    ssh-keygen -t rsa -q -f /var/lib/oar/.ssh/id_rsa -N '' || true
    cat /var/lib/oar/.ssh/id_rsa.pub > /var/lib/oar/.ssh/authorized_keys || true
    cat <<EOF > /var/lib/oar/.ssh/config || true
Host *
    ForwardX11 no
    StrictHostKeyChecking no
    PasswordAuthentication no
    AddressFamily inet
EOF
    chown oar:oar /var/lib/oar/.ssh -R || true
fi
chkconfig --add oar-server

%preun server
/etc/init.d/oar-server stop 2>/dev/null || true


###### oar-node scripts ######

%post node
# create oar sshd keys
if [ ! -r /etc/oar/oar_ssh_host_rsa_key ]; then
    rm -f /etc/oar/oar_ssh_host_rsa_key.pub
    cp /etc/ssh/ssh_host_rsa_key /etc/oar/oar_ssh_host_rsa_key
    cp /etc/ssh/ssh_host_rsa_key.pub /etc/oar/oar_ssh_host_rsa_key.pub
fi

if [ ! -r /etc/oar/oar_ssh_host_dsa_key ]; then
    rm -f /etc/oar/oar_ssh_host_dsa_key.pub
    cp /etc/ssh/ssh_host_dsa_key /etc/oar/oar_ssh_host_dsa_key
    cp /etc/ssh/ssh_host_dsa_key.pub /etc/oar/oar_ssh_host_dsa_key.pub
fi
chkconfig --add oar-node

%preun node
/etc/init.d/oar-node stop 2>/dev/null|| true

%postun node
if [ "$1" = 0 ];
then
  chsh -s /bin/bash oar 2>/dev/null || true
fi

###### oar-web-status scripts ######

%post web-status
mkdir -p /var/lib/drawgantt-files/cache && chown apache /var/lib/drawgantt-files/cache || true
ln -s /etc/oar/apache.conf /etc/httpd/conf.d/oar-web-status.conf || true
service httpd reload || true

%postun web-status
if [ "$1" = "0" ] ; then # last uninstall
  rm -f /etc/httpd/conf.d/oar-web-status.conf || true
  rm -rf /var/lib/drawgantt-files/cache
fi

###### oar-api scripts ######

%post api
ln -s /etc/oar/apache-api.conf /etc/httpd/conf.d/oar-api.conf || true
service httpd reload || true

%post gridapi
ln -s /etc/oar/apache-gridapi.conf /etc/httpd/conf.d/oar-gridapi.conf || true
service httpd reload || true

%postun api
if [ "$1" = "0" ] ; then # last uninstall
  rm -f /etc/httpd/conf.d/oar-api.conf || true
  service httpd reload || true
fi

%postun gridapi
if [ "$1" = "0" ] ; then # last uninstall
  rm -f /etc/httpd/conf.d/oar-gridapi.conf || true
  service httpd reload || true
fi

%changelog
* Wed Nov 4 2009 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.4.0-5
- Released 2.4.0

* Wed Nov 4 2009 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.4.0-4test
- Added oar-gridapi package
- fixed dependencies with oarnodes and oarstat libs
- fixed api packaging

* Thu Sep 24 2009 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.4.0-3test
- Changed oar-web-status files paths
- improved init script

* Thu Jun 25 2009 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.4.0-2test
- Bug fix: upgrade of oar-web-status and oar-api packages removed some files

* Mon Jan 26 2009 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.4.0-1test
- First RPM packaging for 2.4 branch.
- Added oar-api package

* Sun Mar 23 2008 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.3.0-1
- First RPM packaging for 2.3 branch. Inspired from 1.6 RPM packaging and 2.3 Debian packaging.


%define version 2.5.0+dev504.051c245
%define release 1centos6

%define oaruser  oar

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
BuildRoot:      %{_tmppath}/oar-%{version}-%{release}-build
BuildRequires:  perl sed make tar python-docutils
%description
OAR is a resource manager (or batch scheduler) for large computing clusters.

%package common
Summary:        OAR batch scheduler common package
Group:          System/Servers
Requires:       perl, shadow-utils, perl-DBI
  # How could we do (libdbd-mysql-perl | libdbd-pg-perl) ?
%description common
This package installs the common part or the OAR batch scheduler

%package -n perl-OAR
Summary:        OAR batch scheduler common perl library package
Group:          System/Servers
Requires:       perl(DBI)
Provides:       perl(OAR::IO), perl(OAR::Modules::Judas), perl(OAR::Tools), perl(OAR::Conf), perl(OAR::Schedulers::ResourceTree), perl(OAR::Version), perl(OAR::Stat), perl(OAR::Nodes), perl(OAR::Sub)
%description -n perl-OAR
This package installs the common libraries of the OAR batch scheduler

%package server-mysql
Summary:        OAR batch scheduler MySQL backend package for the server
Group:          System/Servers
Requires:       oar-server, perl-DBD-MySQL
%description server-mysql
This package installs the MySQL backend for the server part or the OAR batch scheduler

%package server-pgsql
Summary:        OAR batch scheduler PostgreSQL backend package for the server
Group:          System/Servers
Requires:       oar-server, perl-DBD-Pg
%description server-pgsql
This package installs the PostgreSQL backend for the server part or the OAR batch scheduler

%package server
Summary:        OAR batch scheduler server package
Group:          System/Servers
Requires:       oar-common = %version-%release, perl-OAR =  %version-%release, /usr/bin/ssh, /usr/sbin/sshd, /etc/cron.d, /lib/lsb/init-functions
%description server
This package installs the server part or the OAR batch scheduler

%package node
Summary:	OAR batch scheduler node package
Group:          System/Servers
Requires:       oar-common = %version-%release, /usr/bin/ssh, /usr/sbin/sshd, /lib/lsb/init-functions
%description node
This package installs the execution node part of the OAR batch scheduler

%package user-mysql
Summary:	OAR batch scheduler user MySQL backend package
Group:          System/Servers
Requires:       oar-user, perl-DBD-MySQL
%description user-mysql
This package install the MySQL backend for the submission and query part of the OAR batch scheduler

%package user-pgsql
Summary:	OAR batch scheduler user PostgreSQL backend package
Group:          System/Servers
Requires:       oar-user, perl-DBD-Pg
%description user-pgsql
This package install the PostgreSQL backend for the submission and query part of the OAR batch scheduler

%package user
Summary:	OAR batch scheduler user package
Group:          System/Servers
Requires:       oar-common = %version-%release, perl-OAR =  %version-%release, /usr/bin/ssh
%description user
This package install the submission and query part of the OAR batch scheduler

%package web-status
Summary:	OAR batch scheduler web-status package
Group:          System/Servers
Requires:       ruby, perl-DBI, perl-Tie-IxHash, perl-AppConfig, ruby-DBI, ruby-GD, perl(Sort::Naturally), httpd
 # Some Ruby dependencies missing (libdbd-mysql-ruby|libdbd-pg-ruby)
Provides:       Perl(OAR::Monika), DrawGantt
%description web-status
This package installs the OAR batch scheduler Gantt reservation diagram CGI: DrawGantt and the instant cluster state visualization CGI: Monika

%package doc
Summary:	OAR batch scheduler doc package
Group:          System/Servers
Requires:       man, httpd
#BuildRequires:  python-docutils, httpd
%description doc
This package installs some documentation for OAR batch scheduler

%package admin
Summary:	OAR batch scheduler administration tools package
Group:          System/Servers
Requires:       oar-common = %version-%release, ruby, ruby-DBI, perl(YAML)
%description admin
This package installs some useful tools to help the administrator of a oar server (resources manipulation, admission rules edition, ...) 

%package desktop-computing-agent
Summary:        OAR desktop computing agent
Group:          System/Servers
Requires:	oar-common = %version-%release, ruby
%description desktop-computing-agent
This package install the OAR batch scheduler desktop computing agent

%package desktop-computing-cgi
Summary:	OAR desktop computing HTTP proxy CGI
Group:          System/Servers
Requires:	perl(CGI), oar-common = %version-%release, httpd
%description    desktop-computing-cgi	
This package install the OAR batch scheduler desktop computing HTTP proxy CGI

%package api
Summary:	OAR RESTful user API
Group:          System/Servers
Requires:	perl(CGI), oar-common >= 2.4.0-1, oar-user >= 2.4.0-1, httpd
Provides:       perl(OAR::API)
%description    api
This package installs the RESTful OAR user API.

#%package scheduler-ocaml-mysql
#Summary:        OAR batch scheduler package for ocaml schedular
#Group:          System/Servers
#Requires:       oar-server, ocaml-mysql, rubygem-sequel
#BuildArch:      amd64 i686

%prep
%setup -T -b 0

# Modify Makefile for chown commands to be non-fatal as the permissions
# are set by the packaging
#for file in Makefiles/*.mk; do
#    perl -i -pe "s/chown/-chown/" $file
#    perl -i -pe "s/-o root//" $file
#    perl -i -pe "s/-g root//" $file
#done
#perl -i -pe "s/chown/-chown/" Makefile
#perl -i -pe "s/-o root//" Makefile
#perl -i -pe "s/-g root//" Makefile
#
%build
export OARUSER=%{oaruser}
export SETUP_TYPE=rpm
export TARGET_DIST=redhat
mkdir tmp/
make packages-build PACKAGES_DIR=tmp

%install
export SETUP_TYPE=rpm
export TARGET_DIST=redhat
# Install into separated directories using the provided makefile
make packages-install PACKAGES_DIR=tmp

# Get the file lists for every package (except those explicitely listed later)
for package in oar-common oar-server oar-node oar-user oar-web-status oar-doc oar-admin oar-desktop-computing-agent oar-desktop-computing-cgi oar-api liboar-perl
do
  ( cd tmp/$package && ( find -type f && find -type l ) | sed 's#^.##' ) \
    | sed -e "s/\.1$/.1.gz/g" > $package.files
done

# common
TMP=tmp/oar-common
mkdir -p $TMP/etc/oar
mkdir -p $TMP/etc/logrotate.d
cp $TMP/usr/share/doc/oar-common/examples/oar.conf \
   $TMP/usr/share/doc/oar-common/examples/oarnodesetting_ssh \
   $TMP/usr/share/doc/oar-common/examples/update_cpuset_id.sh \
     $TMP/etc/oar/

cp $TMP/usr/share/doc/oar-common/examples/logrotate.d/oar-common \
      $TMP/etc/logrotate.d/oar

# api
TMP=tmp/oar-api
mkdir -p $TMP/etc/oar
cp $TMP/usr/share/doc/oar-api/examples/apache2.conf \
     $TMP/etc/oar/apache-api.conf
cp $TMP/usr/share/doc/oar-api/examples/api_html_header.pl \
   $TMP/usr/share/doc/oar-api/examples/api_html_postform.pl \
   $TMP/usr/share/doc/oar-api/examples/api_html_postform_resources.pl \
   $TMP/usr/share/doc/oar-api/examples/api_html_postform_rule.pl \
     $TMP/etc/oar/

# web-status
TMP=tmp/oar-web-status
mkdir -p $TMP/etc/oar
cp $TMP/usr/share/doc/oar-web-status/examples/drawgantt.conf \
   $TMP/usr/share/doc/oar-web-status/examples/monika.conf \
   $TMP/usr/share/doc/oar-web-status/examples/apache.conf \
     $TMP/etc/oar

# node
TMP=tmp/oar-node
mkdir -p $TMP/etc/oar
mkdir -p $TMP/etc/cron.d
mkdir -p $TMP/etc/rc.d/init.d
mkdir -p $TMP/etc/sysconfig
cp $TMP/usr/share/doc/oar-node/examples/epilogue \
   $TMP/usr/share/doc/oar-node/examples/prologue \
   $TMP/usr/share/doc/oar-node/examples/sshd_config \
     $TMP/etc/oar

#cp $TMP/usr/share/doc/oar-node/examples/cron.d/oar-node \
#     $TMP/etc/cron.d/oar-node
cp $TMP/usr/share/doc/oar-node/examples/init.d/oar-node \
     $TMP/etc/rc.d/init.d/oar-node
cp $TMP/usr/share/doc/oar-node/examples/default/oar-node \
     $TMP/etc/sysconfig/oar-node
 
# server 
TMP=tmp/oar-server
mkdir -p $TMP/etc/oar
mkdir -p $TMP/etc/sysconfig
mkdir -p $TMP/etc/rc.d/init.d
mkdir -p $TMP/etc/cron.d
cp $TMP/usr/share/doc/oar-server/examples/job_resource_manager.pl \
   $TMP/usr/share/doc/oar-server/examples/suspend_resume_manager.pl \
   $TMP/usr/share/doc/oar-server/examples/oarmonitor_sensor.pl \
   $TMP/usr/share/doc/oar-server/examples/wake_up_nodes.sh \
   $TMP/usr/share/doc/oar-server/examples/shut_down_nodes.sh \
   $TMP/usr/share/doc/oar-server/examples/server_prologue \
   $TMP/usr/share/doc/oar-server/examples/server_epilogue \
     $TMP/etc/oar

cp $TMP/usr/share/doc/oar-server/examples/cron.d/oar-server \
     $TMP/etc/cron.d/oar-server
cp $TMP/usr/share/doc/oar-server/examples/init.d/oar-server \
     $TMP/etc/rc.d/init.d/oar-server
cp $TMP/usr/share/doc/oar-server/examples/default/oar-server \
     $TMP/etc/sysconfig/oar-server

# desktop-computing-cgi
TMP=tmp/oar-desktop-computing-cgi
mkdir -p $TMP/etc/oar
mkdir -p $TMP/etc/cron.hourly
cp $TMP/usr/share/doc/oar-desktop-computing-cgi/examples/cron.hourly/oar-desktop-computing-cgi \
     $TMP/etc/cron.hourly/oar-desktop-computing-cgi  

# Reconstruct the whole system
mkdir -p $RPM_BUILD_ROOT
rm -rf $RPM_BUILD_ROOT/*
cp -a tmp/*/* $RPM_BUILD_ROOT/

# Additional distribution dependent files
mkdir -p $RPM_BUILD_ROOT/var/lib/oar/checklogs



%clean
make packages-clean PACKAGES_DIR=tmp
rm -rf $RPM_BUILD_ROOT/*
rm -rf tmp


###### files and permissions ######

%files common -f oar-common.files
%config /etc/oar/oar.conf 
%config /etc/oar/oarnodesetting_ssh
%config /etc/oar/update_cpuset_id.sh
%config %attr(0755,root,root) /etc/logrotate.d/oar

%files server -f oar-server.files
%config %attr(0755,root,root) /etc/rc.d/init.d/oar-server
%config %attr(0644,root,root) /etc/sysconfig/oar-server
%config %attr(0644,root,root) /etc/cron.d/oar-server
%config /etc/oar/job_resource_manager.pl
%config /etc/oar/oarmonitor_sensor.pl
%config /etc/oar/server_epilogue
%config /etc/oar/server_prologue
%config /etc/oar/suspend_resume_manager.pl
%config /etc/oar/oar_phoenix.pl
%config /etc/oar/shut_down_nodes.sh
%config /etc/oar/wake_up_nodes.sh

%files server-mysql

%files server-pgsql

%files node -f oar-node.files
%config %attr(0755,root,root) /etc/rc.d/init.d/oar-node
%config %attr(0644,root,root) /etc/sysconfig/oar-node
#%config %attr(0644,root,root) /etc/cron.d/oar-node
%config /etc/oar/epilogue
%config /etc/oar/prologue
%config /etc/oar/sshd_config
%config /etc/oar/check.d
%config /var/lib/oar/checklogs

%files user -f oar-user.files

%files user-mysql

%files user-pgsql

%files web-status -f oar-web-status.files
%config %attr (0600,apache,root) /etc/oar/drawgantt.conf
%config %attr (0600,apache,root) /etc/oar/monika.conf
%config %attr (0600,apache,root) /etc/oar/apache.conf

%files doc -f oar-doc.files
%docdir /usr/share/doc/oar-doc 

%files admin -f oar-admin.files

%files desktop-computing-agent -f oar-desktop-computing-agent.files

%files desktop-computing-cgi -f oar-desktop-computing-cgi.files
%config %attr (0755,root,root) /etc/cron.hourly/oar-desktop-computing-cgi

%files api -f oar-api.files
%config /etc/oar/apache-api.conf
%config /etc/oar/api_html_header.pl
%config /etc/oar/api_html_postform.pl
%config /etc/oar/api_html_postform_resources.pl
%config /etc/oar/api_html_postform_rule.pl

%files -n perl-OAR -f liboar-perl.files

#%files scheduler-ocaml-mysql -f oar-scheduler-ocaml-mysql

###### oar-common scripts ######
%post common
. /usr/lib/oar/setup/common.sh
common_setup

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
. /usr/lib/oar/setup/server.sh
. /usr/lib/oar/setup/database.sh
server_setup
database_setup
chkconfig --add oar-server

%preun server
/etc/init.d/oar-server stop 2>/dev/null || true

###### oar-node scripts ######
%post node
. /usr/lib/oar/setup/node.sh
node_setup
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
. /usr/lib/oar/setup/www-conf.sh
. /usr/lib/oar/setup/monika.sh
. /usr/lib/oar/setup/draw-gantt.sh
www_conf_setup
monika_setup
draw_gantt_setup
ln -s /etc/oar/apache.conf /etc/httpd/conf.d/oar-web-status.conf || true
service httpd reload || true

%postun web-status
if [ "$1" = "0" ] ; then # last uninstall
  rm -f /etc/httpd/conf.d/oar-web-status.conf || true
  rm -rf /var/lib/drawgantt-files/cache
fi

###### oar-api scripts ######
%post api
. /usr/lib/oar/setup/api.sh
api_setup
if [ ! -e /etc/httpd/conf.d/oar-api.conf ]; then
    ln -s /etc/oar/apache-api.conf /etc/httpd/conf.d/oar-api.conf || true
fi
service httpd reload || true

%postun api
if [ "$1" = "0" ] ; then # last uninstall
  rm -f /etc/httpd/conf.d/oar-api.conf || true
  service httpd reload || true
fi

###### oar-admin scripts ######
%post admin
. /usr/lib/oar/setup/tools.sh
tools_setup

###### oar-user scripts ######
%post user
. /usr/lib/oar/setup/user.sh
user_setup


###### oar-desktop-computing-cgi scripts ######
%post desktop-computing-cgi
. /usr/lib/oar/setup/desktop-computing-cgi.sh
desktop_computing_cgi_setup


%changelog
* Thu Nov 10 2011 Philippe Le Brouster <philippe.le-brouster@imag.fr> 2.5.0+dev487.f014a74-1
- Use the setup scripts.

* Thu Jun 17 2010 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.5.0-3
- added poar

* Thu Apr 01 2010 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.5.0-1
- started 2.5.0 packaging
- added oar_phoenix

* Fri Mar 12 2010 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.4.2-2
- Fixed some dependencies

* Wed Nov 4 2009 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 2.4.2-1
- 2.4.2 beta

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


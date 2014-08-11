%define version 2.5.4+rc2
%define release 1.el6

%define oaruser  oar

Name:     oar
Version:  %{version}
Release:  %{release}
Summary:  A versatile HPC cluster task and resource manager (batch scheduler)
License:  GPLv2
Group:    System Environment/Base
Url:      http://oar.imag.fr

%define _topdir %(pwd)
# %define _rpmfilename %%{NAME}-%%{VERSION}-%%{RELEASE}.%%{ARCH}.rpm
# %define _unpackaged_files_terminate_build 0

Source:         oar-%version.tar.gz
BuildRoot:      %{_tmppath}/oar-%{version}-%{release}-build
BuildRequires:  perl sed make tar python-docutils
%description
OAR is a resource manager (or batch scheduler) for large computing clusters.

%package common
Summary:        OAR batch scheduler common package
Group:          System Environment/Base
BuildRequires:  gcc
Requires:       perl, shadow-utils, perl-DBI, coreutils, util-linux-ng
%description common
This package installs the common part or the OAR batch scheduler

%package -n perl-OAR
Summary:        OAR batch scheduler common perl library package
Group:          System Environment/Base
Requires:       perl(DBI)
Provides:       perl(OAR::IO), perl(OAR::Modules::Judas), perl(OAR::Tools), perl(OAR::Conf), perl(OAR::Schedulers::ResourceTree), perl(OAR::Version), perl(OAR::Stat), perl(OAR::Nodes), perl(OAR::Sub)
%description -n perl-OAR
This package installs the common libraries of the OAR batch scheduler

%package server
Summary:        OAR batch scheduler server package
Group:          System Environment/Base
Requires:       oar-common = %version-%release, perl-OAR =  %version-%release, oar-server-backend, openssh-server, openssh-clients, crontabs, redhat-lsb-core
%description server
This package installs the server part or the OAR batch scheduler

%package node
Summary:        OAR batch scheduler node package
Group:          System Environment/Base
Requires:       oar-common = %version-%release, openssh-server, openssh-clients, redhat-lsb-core
%description node
This package installs the execution node part of the OAR batch scheduler

%package user
Summary:        OAR batch scheduler user package
Group:          System Environment/Base
Requires:       oar-common = %version-%release, perl-OAR =  %version-%release, oar-user-backend, openssh-clients
%description user
This package install the submission and query part of the OAR batch scheduler

%package web-status
Summary:        OAR batch scheduler web-status package
Group:          System Environment/Base
Requires:       httpd, perl-DBI, perl-Tie-IxHash, perl-AppConfig, perl(Sort::Naturally), php, oar-web-status-backend = %version-%release
Provides:       Perl(OAR::Monika), DrawGantt-SVG
%description web-status
This package installs the OAR batch scheduler status web pages: jobs and resources status and gantt diagrams.

%package doc
Summary:        OAR batch scheduler doc package
Group:          System Environment/Base
Requires:       man, httpd
BuildRequires:  python-docutils, httpd
%description doc
This package installs some documentation for OAR batch scheduler

%package restful-api
Summary:        OAR RESTful user API
Group:          System Environment/Base
Requires:       oar-common = %version-%release, oar-user = %version-%release, httpd, perl(CGI) 
Provides:       perl(OAR::API), oar-api
Obsoletes:      oar-api
%description    restful-api
This package installs the RESTful OAR user API.

#%package scheduler-ocaml-mysql
#Summary:        OAR batch scheduler package for ocaml schedular
#Group:          System/Servers
#Requires:       oar-server, ocaml-mysql, rubygem-sequel
#BuildArch:      amd64 i686

%package server-mysql
Summary:        OAR batch scheduler MySQL server backend
Group:          System Environment/Base
Requires:       perl-DBD-MySQL
Provides:       oar-server-backend
%description server-mysql
This package installs the MySQL dependencies for OAR server package

%package server-pgsql
Summary:        OAR batch scheduler PostgreSQL server backend
Group:          System Environment/Base
Requires:       perl-DBD-Pg
Provides:       oar-server-backend
%description server-pgsql
This package installs the PostgreSQL dependencies for OAR server package

%package user-mysql
Summary:        OAR batch scheduler MySQL user backend
Group:          System Environment/Base
Requires:       perl-DBD-MySQL
Provides:       oar-user-backend
%description user-mysql
This package installs the MySQL dependencies for OAR user package

%package user-pgsql
Summary:        OAR batch scheduler PostgreSQL user backend
Group:          System Environment/Base
Requires:       perl-DBD-Pg
Provides:       oar-user-backend
%description user-pgsql
This package installs the PostgreSQL dependencies for OAR user package

%package web-status-mysql
Summary:        OAR batch scheduler MySQL web-status backend
Group:          System Environment/Base
Requires:       perl-DBD-MySQL, php-mysql
Provides:       oar-web-status-backend
%description web-status-mysql
This package installs the MySQL dependencies for OAR web-status package

%package web-status-pgsql
Summary:        OAR batch scheduler PostgreSQL web-status backend
Group:          System Environment/Base
Requires:       perl-DBD-Pg, php-pgsql
Provides:       oar-web-status-backend
%description web-status-pgsql
This package installs the PostgreSQL dependencies for OAR web-status package

%prep
%setup -q

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
for package in oar-common oar-server oar-node oar-user oar-web-status oar-doc oar-restful-api liboar-perl
do
  ( cd tmp/$package && ( find -type f && find -type l ) | sed 's#^.##' ) \
    | sed -e "s/\.1$/.1.gz/g" > $package.files
done

# common
TMP=tmp/oar-common
mkdir -p $TMP/etc/oar
mkdir -p $TMP/etc/logrotate.d
cp $TMP/usr/share/oar/oar-common/oar.conf \
   $TMP/usr/share/oar/oar-common/oarnodesetting_ssh \
   $TMP/usr/share/oar/oar-common/update_cpuset_id.sh \
     $TMP/etc/oar/

cp $TMP/usr/share/oar/oar-common/logrotate.d/oar-common \
      $TMP/etc/logrotate.d/oar

# bug fix
sed -e "s/groupadd --quiet/groupadd/" -i $TMP/usr/lib/oar/setup/common.sh

# restful-api
TMP=tmp/oar-restful-api
mkdir -p $TMP/etc/oar
cp $TMP/usr/share/oar/oar-api/apache2.conf \
     $TMP/etc/oar/apache-api.conf
cp $TMP/usr/share/oar/oar-api/api_html_header.pl \
   $TMP/usr/share/oar/oar-api/api_html_postform.pl \
   $TMP/usr/share/oar/oar-api/api_html_postform_resources.pl \
   $TMP/usr/share/oar/oar-api/api_html_postform_rule.pl \
   $TMP/usr/share/oar/oar-api/stress_factor.sh \
     $TMP/etc/oar/

# web-status
TMP=tmp/oar-web-status
mkdir -p $TMP/etc/oar
cp $TMP/usr/share/oar/oar-web-status/drawgantt-config.inc.php \
   $TMP/usr/share/oar/oar-web-status/monika.conf \
   $TMP/usr/share/oar/oar-web-status/apache.conf \
     $TMP/etc/oar

# node
TMP=tmp/oar-node
mkdir -p $TMP/etc/oar
mkdir -p $TMP/etc/cron.d
mkdir -p $TMP/etc/rc.d/init.d
mkdir -p $TMP/etc/sysconfig
cp $TMP/usr/share/oar/oar-node/epilogue \
   $TMP/usr/share/oar/oar-node/prologue \
   $TMP/usr/share/oar/oar-node/sshd_config \
     $TMP/etc/oar

#cp $TMP/usr/share/oar/oar-node/cron.d/oar-node \
#     $TMP/etc/cron.d/oar-node
cp $TMP/usr/share/oar/oar-node/init.d/oar-node \
     $TMP/etc/rc.d/init.d/oar-node
cp $TMP/usr/share/oar/oar-node/default/oar-node \
     $TMP/etc/sysconfig/oar-node
 
# server 
TMP=tmp/oar-server
mkdir -p $TMP/etc/oar
mkdir -p $TMP/etc/sysconfig
mkdir -p $TMP/etc/rc.d/init.d
mkdir -p $TMP/etc/cron.d
cp $TMP/usr/share/oar/oar-server/job_resource_manager.pl \
   $TMP/usr/share/oar/oar-server/job_resource_manager_cgroups.pl \
   $TMP/usr/share/oar/oar-server/suspend_resume_manager.pl \
   $TMP/usr/share/oar/oar-server/oarmonitor_sensor.pl \
   $TMP/usr/share/oar/oar-server/wake_up_nodes.sh \
   $TMP/usr/share/oar/oar-server/shut_down_nodes.sh \
   $TMP/usr/share/oar/oar-server/server_prologue \
   $TMP/usr/share/oar/oar-server/server_epilogue \
   $TMP/usr/share/oar/oar-server/scheduler_quotas.conf \
     $TMP/etc/oar

cp $TMP/usr/share/oar/oar-server/cron.d/oar-server \
     $TMP/etc/cron.d/oar-server
cp $TMP/usr/share/oar/oar-server/init.d/oar-server \
     $TMP/etc/rc.d/init.d/oar-server
cp $TMP/usr/share/oar/oar-server/default/oar-server \
     $TMP/etc/sysconfig/oar-server

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
# Override the definition of %{_libdir} = /uar/lib instead of /usr/lib64 on 64bits systems
%define _libdir %{_exec_prefix}/lib

%files common -f oar-common.files
%defattr(0644,root,root)
%config(noreplace) %attr(0600, oar, root) %{_sysconfdir}/oar/oar.conf
%config(noreplace) %attr(0755, root, root) %{_sysconfdir}/oar/oarnodesetting_ssh
%config(noreplace) %attr(0755, root, root) %{_sysconfdir}/oar/update_cpuset_id.sh
%config %attr(0755,root,root) %{_sysconfdir}/logrotate.d/oar
%attr(0755, root, root) %{_bindir}/oarsh
%attr(0755, root, root) %{_bindir}/oarprint
%attr(0755, root, root) %{_bindir}/oarcp
%attr(0755, root, root) %{_libdir}/oar/oarsh_shell
%attr(0755, root, root) %{_libdir}/oar/oarnodesetting
%attr(0755, root, root) %{_libdir}/oar/oarsh
%attr(0755, root, root) %{_libdir}/oar/setup/common.sh
%attr(0755, root, root) %{_libdir}/oar/sentinelle.pl
%attr(6755, root, oar) %{_libdir}/oar/oarsh_oardo
%attr(6754, root, oar) %{_sbindir}/oarnodesetting
%attr(6754, root, oar) %{_libdir}/oar/oardodo/oardodo

%files server -f oar-server.files
%defattr(0644,root,root)
%config %attr(0755,root,root) %{_sysconfdir}/rc.d/init.d/oar-server
%config(noreplace) %attr(0644,root,root) %{_sysconfdir}/sysconfig/oar-server
%config %attr(0644,root,root) %{_sysconfdir}/cron.d/oar-server
%config(noreplace) %{_sysconfdir}/oar/job_resource_manager.pl
%config(noreplace) %{_sysconfdir}/oar/job_resource_manager_cgroups.pl
%config(noreplace) %{_sysconfdir}/oar/oarmonitor_sensor.pl
%config(noreplace) %{_sysconfdir}/oar/server_epilogue
%config(noreplace) %{_sysconfdir}/oar/server_prologue
%config(noreplace) %{_sysconfdir}/oar/suspend_resume_manager.pl
%config(noreplace) %attr(0755,root,root) %{_sysconfdir}/oar/oar_phoenix.pl
%config(noreplace) %{_sysconfdir}/oar/shut_down_nodes.sh
%config(noreplace) %{_sysconfdir}/oar/wake_up_nodes.sh
%config(noreplace) %{_sysconfdir}/oar/scheduler_quotas.conf
%attr(0755, root, root) %{_sbindir}/oar-database
%attr(0755, root, root) %{_sbindir}/oar-server
%attr(6754, root, oar) %{_sbindir}/Almighty
%attr(6754, root, oar) %{_sbindir}/oar_checkdb
%attr(6754, root, oar) %{_sbindir}/oar_phoenix
%attr(6754, root, oar) %{_sbindir}/oar_resources_init
%attr(6754, root, oar) %{_sbindir}/oaraccounting
%attr(6754, root, oar) %{_sbindir}/oarmonitor
%attr(6754, root, oar) %{_sbindir}/oarnotify
%attr(6754, root, oar) %{_sbindir}/oarproperty
%attr(6754, root, oar) %{_sbindir}/oarremoveresource
%attr(0755, root, root) %{_libdir}/oar/Almighty
%attr(0755, root, root) %{_libdir}/oar/Leon
%attr(0755, root, root) %{_libdir}/oar/NodeChangeState
%attr(0755, root, root) %{_libdir}/oar/bipbip
%attr(0755, root, root) %{_libdir}/oar/finaud
%attr(0755, root, root) %{_libdir}/oar/oar_checkdb.pl
%attr(0755, root, root) %{_libdir}/oar/oar_meta_sched
%attr(0755, root, root) %{_libdir}/oar/oar_resources_init
%attr(0755, root, root) %{_libdir}/oar/oaraccounting
%attr(0755, root, root) %{_libdir}/oar/oarmonitor
%attr(0755, root, root) %{_libdir}/oar/oarnotify
%attr(0755, root, root) %{_libdir}/oar/oarproperty
%attr(0755, root, root) %{_libdir}/oar/oarremoveresource
%attr(0755, root, root) %{_libdir}/oar/sarko
%attr(0755, root, root) %{_libdir}/oar/schedulers/oar_sched_gantt_with_timesharing
%attr(0755, root, root) %{_libdir}/oar/schedulers/oar_sched_gantt_with_timesharing_and_fairsharing
%attr(0755, root, root) %{_libdir}/oar/schedulers/oar_sched_gantt_with_timesharing_and_fairsharing_and_placeholder
%attr(0755, root, root) %{_libdir}/oar/schedulers/oar_sched_gantt_with_timesharing_and_fairsharing_and_quotas
%attr(0755, root, root) %{_libdir}/oar/schedulers/oar_sched_gantt_with_timesharing_and_placeholder
%attr(0755, root, root) %{_libdir}/oar/setup/database.sh
%attr(0755, root, root) %{_libdir}/oar/setup/server.sh
%attr(0755, root, root) %{_libdir}/oar/NodeChangeState

%files node -f oar-node.files
%defattr(0644,root,root)
%config %attr(0755,root,root) %{_sysconfdir}/rc.d/init.d/oar-node
%config(noreplace) %attr(0644,root,root) %{_sysconfdir}/sysconfig/oar-node
%config(noreplace) %{_sysconfdir}/oar/epilogue
%config(noreplace) %{_sysconfdir}/oar/prologue
%config(noreplace) %attr(0600, oar, root) %{_sysconfdir}/oar/sshd_config
%config(noreplace) %{_sysconfdir}/oar/check.d
%config(noreplace) %{_sharedstatedir}/oar/checklogs
%attr(0755, root, root) %{_bindir}/oarnodecheckquery
%attr(0755, root, root) %{_bindir}/oarnodechecklist
%attr(0755, root, root) %{_libdir}/oar/setup/node.sh
%attr(0755, root, root) %{_libdir}/oar/oarnodecheckrun

%files user -f oar-user.files
%defattr(0644,root,root)
%attr(6755, root, oar) %{_bindir}/oarstat
%attr(6755, root, oar) %{_bindir}/oarnodes
%attr(6755, root, oar) %{_bindir}/oarresume
%attr(6755, root, oar) %{_bindir}/oarhold
%attr(6755, root, oar) %{_bindir}/oardel
%attr(6755, root, oar) %{_bindir}/oarsub
%attr(0755, root, root) %{_bindir}/oarmonitor_graph_gen
%attr(0755, root, root) %{_libdir}/oar/oarstat
%attr(0755, root, root) %{_libdir}/oar/setup/user.sh
%attr(0755, root, root) %{_libdir}/oar/oarnodes
%attr(0755, root, root) %{_libdir}/oar/oarresume
%attr(0755, root, root) %{_libdir}/oar/oarhold
%attr(0755, root, root) %{_libdir}/oar/oardel
%attr(0755, root, root) %{_libdir}/oar/oarsub

%files web-status -f oar-web-status.files
%defattr(0644,root,root)
%config(noreplace) %attr (0600,apache,root) %{_sysconfdir}/oar/drawgantt-config.inc.php
%config(noreplace) %attr (0600,apache,root) %{_sysconfdir}/oar/monika.conf
%config(noreplace) %attr (0600,apache,root) %{_sysconfdir}/oar/apache.conf
%attr(0755, root, root) /var/www/cgi-bin/monika.cgi
%attr(0755, root, root) %{_libdir}/oar/setup/www-conf.sh
%attr(0755, root, root) %{_libdir}/oar/setup/drawgantt-svg.sh
%attr(0755, root, root) %{_libdir}/oar/setup/monika.sh

%files doc -f oar-doc.files
%defattr(0644,root,root)
%docdir %{_docdir}/oar-doc 

%files restful-api -f oar-restful-api.files
%defattr(0644,root,root)
%config(noreplace) %{_sysconfdir}/oar/apache-api.conf
%config %{_sysconfdir}/oar/api_html_header.pl
%config %{_sysconfdir}/oar/api_html_postform.pl
%config %{_sysconfdir}/oar/api_html_postform_resources.pl
%config %{_sysconfdir}/oar/api_html_postform_rule.pl
%config %{_sysconfdir}/oar/stress_factor.sh
%attr(6755, root, oar) /var/www/cgi-bin/oarapi/oarapi-debug.cgi
%attr(6755, root, oar) /var/www/cgi-bin/oarapi/oarapi.cgi
%attr(0755, root, root) %{_libdir}/oar/oarapi.pl
%attr(0755, root, root) %{_libdir}/oar/setup/api.sh

%files -n perl-OAR -f liboar-perl.files
%defattr(0644,root,root)

#%files scheduler-ocaml-mysql -f oar-scheduler-ocaml-mysql

%files server-mysql
%defattr(0644,root,root)

%files server-pgsql
%defattr(0644,root,root)

%files user-mysql
%defattr(0644,root,root)

%files user-pgsql
%defattr(0644,root,root)

%files web-status-mysql
%defattr(0644,root,root)

%files web-status-pgsql
%defattr(0644,root,root)

###### oar-common scripts ######
%post common
. %{_libdir}/oar/setup/common.sh
common_setup

%postun common
if [ "$1" = 0 ];
then
  userdel oar &> /dev/null || true
  groupdel oar &> /dev/null || true
  rm -f %{_localstatedir}/log/oar.log* || true
  rm -rf %{_localstatedir}/run/oar || true
fi

###### oar-server scripts ######
%post server
. %{_libdir}/oar/setup/server.sh
. %{_libdir}/oar/setup/database.sh
server_setup
database_setup
chkconfig --add oar-server

%preun server
%{_sysconfdir}/init.d/oar-server stop 2>/dev/null || true

###### oar-node scripts ######
%post node
. %{_libdir}/oar/setup/node.sh
node_setup
chkconfig --add oar-node

%preun node
%{_sysconfdir}/init.d/oar-node stop 2>/dev/null|| true

%postun node
if [ "$1" = 0 ];
then
  chsh -s /bin/bash oar 2>/dev/null || true
fi

###### oar-web-status scripts ######
%post web-status
. %{_libdir}/oar/setup/www-conf.sh
. %{_libdir}/oar/setup/monika.sh
. %{_libdir}/oar/setup/drawgantt-svg.sh
www_conf_setup
monika_setup
drawgantt_svg_setup
service httpd reload || true

%postun web-status
if [ "$1" = "0" ] ; then # last uninstall
  rm -f %{_sysconfdir}/httpd/conf.d/oar-web-status.conf || true
fi

###### oar-restful-api scripts ######
%post restful-api
. %{_libdir}/oar/setup/api.sh
api_setup
service httpd reload || true

%postun restful-api
if [ "$1" = "0" ] ; then # last uninstall
  rm -f %{_sysconfdir}/httpd/conf.d/oar-api.conf || true
  service httpd reload || true
fi

###### oar-user scripts ######
%post user
. %{_libdir}/oar/setup/user.sh
user_setup


%changelog
* Wed Aug 5 2014 Pierre Neyron <pierre.neyron@imag.fr> 2.5.4-1.el6
- New upstream release
- Removed dependancies on ruby: removed oar-admin and its associated backends, removed drawgantt
- Do not package runner, since it vanished from sources
- Adapt paths due to the disappearing of the use of the examples directories
- Fix hard-coded paths using macros, to please rpmlint

* Wed Jun 19 2013 Pierre Neyron <pierre.neyron@imag.fr> 2.5.3-1.el6
- New upstream release
- Remove OAR desktop-computing packages
- Add packaging for drawgantt-svg
- Fix some rpmlint warnings
- Make dependancy more accurate for Centos 6
- Improve the database libs dependency resolution for Perl/Ruby/php
- Fix serveral errors

* Wed May 23 2012 Philippe Le Brouster <philippe.le-brouster@imag.fr> 2.5.2-1.el6
- new upstream release

* Thu Jan 18 2012 Philippe Le Brouster <philippe.le-brouster@imag.fr> 2.5.1-2.el6
- Fix require bug for oar-server and oar-user.
- Install the file 'job_resource_manager_cgroups.pl'

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


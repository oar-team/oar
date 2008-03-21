%define version 2.3.0
%define release 1

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

Source0: 	oar_%version.tar.gz
Source1:	Makefile.install
BuildRoot:      %{_tmppath}/oar-%{version}-%{release}-build
BuildRequires:  perl sed make tar xauth
BuildArch: 	noarch
%description
OAR is a resource manager (or batch scheduler) for large computing clusters.

%package common
Summary:        OAR batch scheduler common package
Group:          System/Servers
BuildArch: 	noarch
Requires:       perl, perl-suidperl, shadow-utils, perl-DBI
  # How could we do (libdbd-mysql-perl | libdbd-pg-perl) ?
Provides: 	perl(oar_iolib), perl(oar_Judas), perl(oar_Tools), perl(oar_conflib), perl(oar_resource_tree), perl(oarversion)
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
Requires:       ruby, perl-DBI, perl-Tie-IxHash, perl-AppConfig
 # Some Ruby dependencies missing (libdbd-mysql-ruby|libdbd-pg-ruby, libgd-ruby1.8)
BuildArch: 	noarch
Provides:	perl(monika::Sort::Naturally), Monika, DrawGantt
%description web-status
This package install the OAR batch scheduler Gantt reservation diagram CGI: DrawGantt and the instant cluster state visualization CGI: Monika

%package doc
Summary:	OAR batch scheduler doc package
Group:          System/Servers
Requires:       man
BuildArch: 	noarch
BuildRequires:  python-docutils, httpd
%description doc
This package install some documentation for OAR batch scheduler

%prep
%setup -T -b 0
cp %{_topdir}/SOURCES/Makefile.install .

%build
# Install into separated directories using a specific Makefile
make -f Makefile.install pkginstall BUILDDIR=tmp WWWUSER=apache
mkdir -p $RPM_BUILD_ROOT
# Reconstruct the whole system
cp -a tmp/*/* $RPM_BUILD_ROOT/
# Get the file lists for every package
for package in oar-common oar-server oar-node oar-user oar-web-status oar-doc
do
  ( cd tmp/$package && ( find -type f && find -type l ) | sed 's#^.##' ) > $package.files
done

%clean
#rm -rf $RPM_BUILD_ROOT
#rm -rf tmp

%files common -f oar-common.files
%files server -f oar-server.files
%files node -f oar-node.files
%files user -f oar-user.files
%files web-status -f oar-web-status.files
%files doc -f oar-doc.files



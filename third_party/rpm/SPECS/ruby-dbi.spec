Summary: A database independent API to access databases
Name: ruby-DBI
%define tarname dbi
Version: 0.2.0
Release: 2%{?dist}
License: public domain
Group: Applications/Ruby
Source: http://rubyforge.org/frs/download.php/12368/ruby-dbi/%{tarname}-%{version}.tar.gz
URL: http://ruby-dbi.rubyforge.org/
Packager: Ian Macdonald <ian@caliban.org>
BuildRoot:      %{_tmppath}/%{name}-%{version}-build
BuildArch: noarch
BuildRequires: ruby
Requires: ruby >= 1.8.0
Provides: ruby-DBI, ruby-dbi, ruby-dbd-mysql, ruby-DBD-Mysql, ruby-dbd-pg, ruby-DBD-Pg
%define _topdir %(pwd)

%description
A database independent API to access databases, similar to Perl's DBI.

%prep
%setup -n dbi-%{version}
eval sitearchdir=`ruby -r rbconfig -e 'p Config::CONFIG["sitearchdir"]'`
eval sitelibdir=`ruby -r rbconfig -e 'p Config::CONFIG["sitelibdir"]'`
ruby setup.rb config \
     --rb-dir=$RPM_BUILD_ROOT$sitelibdir \
     --so-dir=$RPM_BUILD_ROOT$sitearchdir \
     --bin-dir=$RPM_BUILD_ROOT%{_bindir} \
     --with=dbi,dbd_proxy,dbd_mysql,dbd_msql,dbd_interbase,dbd_oracle,dbd_db2,dbd_ado,dbd_pg,dbd_odbc,dbd_sqlrelay

%build
ruby setup.rb setup

%clean 
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
ruby setup.rb install
find $RPM_BUILD_ROOT%{_prefix} -type f -print | \
  ruby -pe 'sub(%r(^'$RPM_BUILD_ROOT'), "")' > %{name}-%{version}-filelist

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)
%doc ChangeLog LICENSE README
%doc examples/ test/

%changelog
* Tue Jan 24 2012 Philippe Le Brouster <philippe.le-brouster@imag.fr> 0.2.0-2
- update the revision scheme (add the dist as suffix).

* Tue May 13 2008 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 0.2.0-1
- 0.2.0
- builds from local directory
- renamed with caps like perl-DBI

* Mon Oct 30 2006 Ian Macdonald <ian@caliban.org> 0.1.1-1
- 0.1.1

* Mon Feb 20 2006 Ian Macdonald <ian@caliban.org> 0.1.0-1
- 0.1.0

* Mon Dec 27 2004 Ian Macdonald <ian@caliban.org> 0.0.23-1
- 0.0.23

* Fri Apr 23 2004 Ian Macdonald <ian@caliban.org> 0.0.22-1
- 0.0.22

* Tue Sep  9 2003 Ian Macdonald <ian@caliban.org> 0.0.21-1
- 0.0.21

* Fri Jun  6 2003 Ian Macdonald <ian@caliban.org> 0.0.20-1
- 0.0.20

* Sun Apr 27 2003 Ian Macdonald <ian@caliban.org> 0.0.19-1
- 0.0.19

* Tue Oct 22 2002 Ian Macdonald <ian@caliban.org>
- 0.0.18

* Thu Oct  3 2002 Ian Macdonald <ian@caliban.org>
- 0.0.17

* Wed Jul  3 2002 Ian Macdonald <ian@caliban.org>
- 0.0.16

* Tue May 21 2002 Ian Macdonald <ian@caliban.org>
- 0.0.15

* Tue May 14 2002 Ian Macdonald <ian@caliban.org>
- 0.0.14

* Wed Apr 17 2002 Ian Macdonald <ian@caliban.org>
- 0.0.13

* Mon Mar 25 2002 Ian Macdonald <ian@caliban.org>
- updated Source and URL tags

* Mon Mar 18 2002 Ian Macdonald <ian@caliban.org>
- include more documentation from dbd_mysql, dbd_pg and dbi lib directories

* Fri Jan 18 2002 Ian Macdonald <ian@caliban.org>
- 0.0.12

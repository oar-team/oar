Summary: Ruby extension library for using Thomas Boutell's GD library
Name: ruby-GD
%define tarname libgd-ruby
Version: 0.7.4
Release: 1
License: public domain
Group: Applications/Ruby
Source: libgd-ruby_%{version}.tar.gz
URL: http://www.boutell.com/gd/
Packager: Bruno Bzeznik <Bruno.Bzeznik@imag.fr>
BuildRoot: %{_tmppath}/%{name}-%{version}-build
BuildRequires: ruby ruby-devel gd-devel >= 2 libpng-devel zlib-devel
Requires: ruby >= 1.8.0, gd >= 2
Provides: ruby-GD, ruby-gd, libruby-gd

%define _topdir %(pwd)

%description
Ruby extension library for using Thomas Boutell's GD library
This package uses the source from the Debian package at http://packages.debian.org/etch/libgd-ruby1.8

%prep
%setup -n ruby-GD-%{version}
eval sitearchdir=`ruby -r rbconfig -e 'p Config::CONFIG["sitearchdir"]'`
ruby ./extconf.rb \
     --with-xpm \
     --with-freetype \
     --with-ttf \
     --with-jpeg \
     --enable-gd2_0

%build
make

%clean 
rm -rf $RPM_BUILD_ROOT

%install
rm -rf $RPM_BUILD_ROOT
make install DESTDIR=$RPM_BUILD_ROOT
find $RPM_BUILD_ROOT -type f -print | \
  ruby -pe 'sub(%r(^'$RPM_BUILD_ROOT'), "")' > %{name}-%{version}-filelist

%files -f %{name}-%{version}-filelist
%defattr(-,root,root)
%doc readme.en

%changelog
* Tue May 13 2008 Bruno Bzeznik <Bruno.Bzeznik@imag.fr> 0.7.4-1
- Initial package inspired from Debian

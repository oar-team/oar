%define name	ruby-gd
%define version	0.8.0
%define release 3%{?dist}

# Be backportable
%if %(test -n "%ruby_sitearchdir" && echo 1 || echo 0)
%define ruby_sitearchdir %(ruby -rrbconfig -e "puts Config::CONFIG['sitearchdir']")
%endif 


Name:		%{name}
Version:	%{version}
Release:	%{release}
Summary:    An interface to Boutell GD library
Group:      Development/Ruby
License:    BSD-like
URL:        http://rubyforge.org/projects/ruby-gd/
Source:     http://rubyforge.org/frs/download.php/39577/%{name}-%{version}.gem
Provides:   ruby-GD
BuildRequires:  gd-devel
BuildRequires:  ruby-devel
BuildRequires:  freetype-devel
BuildRequires:  libpng-devel
BuildRequires:  zlib-devel
BuildRoot:      %{_tmppath}/%{name}-%{version}

%description
Ruby/GD (formerly known as "GD") is an extension
library to use Thomas Boutell's gd library
(http://www.boutell.com/gd/) from Ruby.

%prep
%setup -c
tar xzf data.tar.gz

%build
ruby extconf.rb --with-jpeg --with-freetype --with-ttf --enable-gd2_0

%install
%makeinstall

%files
%defattr(-,root,root)
%{ruby_sitearchdir}/GD.so



%changelog
* Mon Jan 23 2012 Philippe Le Brouster <philippe.le-brouster@imag.fr> 0.8.0-3el6
- make the sitearchdir definition compatible for centos6/el6.

* Tue Sep 08 2009 Thierry Vignaud <tvignaud@mandriva.com> 0.8.0-2mdv2010.0
+ Revision: 433513
- rebuild

* Thu Aug 14 2008 Guillaume Rousse <guillomovitch@mandriva.org> 0.8.0-1mdv2009.0
+ Revision: 272023
- import ruby-gd


* Thu Aug 14 2008 Guillaume Rousse <guillomovitch@mandriva.org> 0.8.0-1mdv2009.0
- first mdv release

Name:       perl-Sort-Naturally 
Version:    1.02
Release:    9%{?dist}
# see lib/Sort/Naturally.pm 
License:    GPL+ or Artistic
Group:      Development/Libraries
Summary:    Sort lexically, but sort numeral parts numerically 
Source:     http://search.cpan.org/CPAN/authors/id/S/SB/SBURKE/Sort-Naturally-%{version}.tar.gz 
Url:        http://search.cpan.org/dist/Sort-Naturally
BuildArch:  noarch
Requires:   perl(:MODULE_COMPAT_%(eval "`%{__perl} -V:version`"; echo $version))

BuildRequires: perl(ExtUtils::MakeMaker) 
BuildRequires: perl(Test)

%description
This module exports two functions, 'nsort' and 'ncmp'; they are used in
implementing my idea of a "natural sorting" algorithm. Under natural
sorting, numeric substrings are compared numerically, and other
word-characters are compared lexically.

%prep
%setup -q -n Sort-Naturally-%{version}

%build
%{__perl} Makefile.PL INSTALLDIRS=vendor
make %{?_smp_mflags}

%install
make pure_install PERL_INSTALL_ROOT=%{buildroot}
find %{buildroot} -type f -name .packlist -exec rm -f {} ';'
find %{buildroot} -depth -type d -exec rmdir {} 2>/dev/null ';'

%{_fixperms} %{buildroot}/*

%check
make test

%files
%doc ChangeLog README t/ 
%{perl_vendorlib}/*
%{_mandir}/man3/*.3*

%changelog
* Mon Jun 20 2011 Petr Sabata <contyk@redhat.com> - 1.02-9
- Perl mass rebuild in dist-f16-perl (d'oh)
- Remove now obsolete Buildroot and defattr

* Thu Jun 09 2011 Marcela Mašláňová <mmaslano@redhat.com> - 1.02-8
- Perl 5.14 mass rebuild

* Wed Feb 09 2011 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.02-7
- Rebuilt for https://fedoraproject.org/wiki/Fedora_15_Mass_Rebuild

* Wed Dec 22 2010 Marcela Maslanova <mmaslano@redhat.com> - 1.02-6
- 661697 rebuild for fixing problems with vendorach/lib

* Thu May 06 2010 Marcela Maslanova <mmaslano@redhat.com> - 1.02-5
- Mass rebuild with perl-5.12.0

* Mon Dec  7 2009 Stepan Kasal <skasal@redhat.com> - 1.02-4
- rebuild against perl 5.10.1

* Sun Jul 26 2009 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.02-3
- Rebuilt for https://fedoraproject.org/wiki/Fedora_12_Mass_Rebuild

* Thu Feb 26 2009 Fedora Release Engineering <rel-eng@lists.fedoraproject.org> - 1.02-2
- Rebuilt for https://fedoraproject.org/wiki/Fedora_11_Mass_Rebuild

* Sun Oct 05 2008 Chris Weyl <cweyl@alumni.drew.edu> 1.02-1
- initial RPM packaging
- generated with cpan2dist (CPANPLUS::Dist::RPM version 0.0.1)



export OARDO_BUILD     = $(MAKE) -f Makefiles/oardo/oardo.mk build
export OARDO_CLEAN     = $(MAKE) -f Makefiles/oardo/oardo.mk clean
export OARDO_INSTALL   = $(MAKE) -f Makefiles/oardo/oardo.mk install
export OARDO_UNINSTALL = $(MAKE) -f Makefiles/oardo/oardo.mk uninstall


ifndef OARCONFDIR
export OARCONFDIR=/etc/oar
endif
# OARUSER and OAROWNER should be the same value except for special needs 
# (Debian packaging) 
ifndef OARUSER
export OARUSER=oar
endif

ifndef OAROWNER
# OAROWNER is the variable expanded to set the ownership of the files
export OAROWNER=$(OARUSER)
endif

ifndef OAROWNERGROUP
export OAROWNERGROUP=$(OAROWNER)
endif

# Set the user of web server (for CGI installation)
export WWWUSER=www-data

ifndef PREFIX
export PREFIX=/usr/local
endif

ifndef MANDIR 
export MANDIR=$(PREFIX)/man
endif

ifndef OARDIR
export OARDIR=$(PREFIX)/oar
endif

ifndef BINDIR
export BINDIR=$(PREFIX)/bin
endif

ifndef SBINDIR
export SBINDIR=$(PREFIX)/sbin
endif

ifndef DOCDIR
export DOCDIR=$(PREFIX)/doc/oar
endif

ifndef WWWDIR
export WWWDIR=$(PREFIX)/share/oar-www
endif

ifndef CGIDIR
export CGIDIR=$(PREFIX)/lib/cgi-bin
endif

ifndef PERLLIBDIR
export PERLLIBDIR=$(PREFIX)/lib/site_perl
endif

ifndef VARLIBDIR
export VARLIBDIR=/var/lib
endif

ifndef WWW_ROOTDIR
export WWW_ROOTDIR=
endif

ifndef XAUTHCMDPATH
export XAUTHCMDPATH=$(shell which xauth)
endif

ifndef
export XAUTHCMDPATH=/usr/bin/xauth
endif



#! /usr/bin/make

include Makefiles/shared/shared.mk

POAR_DIR=visualization_interfaces/poar

build: 
	# Nohting to do

clean:
	# Nothing to do

install:
	install -d -m 0755 $(DESTDIR)$(WWWDIR)
	install -d -m 0755 $(DESTDIR)$(WWWDIR)/poar
	cp -rf \
	    $(POAR_DIR)/external \
	    $(POAR_DIR)/poar.css  \
	    $(POAR_DIR)/poar.js  \
	    $(POAR_DIR)/resources \
  	    $(POAR_DIR)/User_Manual.txt \
	    $(POAR_DIR)/ext_lib \
	    $(POAR_DIR)/pages \
	    $(POAR_DIR)/poar.html \
	    $(POAR_DIR)/Readme \
	    $(POAR_DIR)/tree-nav-poar.json \
	    $(POAR_DIR)/variables.js \
	    $(DESTDIR)$(WWWDIR)/poar 
	-chown $(WWWUSER) $(DESTDIR)$(WWWDIR)/poar/*
	-chmod 0644 $(DESTDIR)$(WWWDIR)/poar/*

uninstall:
	rm -rf "$(DESTDIR)$(WWWDIR)/poar/"


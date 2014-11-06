#!/bin/bash
# This script install Debian packages needed for tarball make build/install/setup

# Package list
PKG=

## Computing nodes
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
# Common dependencies
PKG="$PKG perl perl-base openssh-client openssh-server"

## Server node
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
# Common dependencies
PKG="$PKG perl perl-base openssh-client openssh-server libdbi-perl libsort-versions-perl"
# MySQL dependencies
PKG="$PKG mysql-server mysql-client libdbd-mysql-perl"
# PostgreSQL dependencies
PKG="$PKG postgresql postgresql-client libdbd-pg-perl"

## Frontend nodes
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
# Common dependencies
PKG="$PKG perl perl-base openssh-client openssh-server libdbi-perl"
# MySQL dependencies
PKG="$PKG mysql-client libdbd-mysql-perl"
# PostgreSQL dependencies
PKG="$PKG postgresql-client libdbd-pg-perl"

## RESTful API
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
# Common dependencies
PKG="$PKG perl perl-base libdbi-perl libjson-perl libyaml-perl libwww-perl apache2.2-bin libcgi-fast-perl"
# FastCGI dependency (optional but highly recommended)
PKG="$PKG libapache2-mod-scgi"
# MySQL dependencies
PKG="$PKG libdbd-mysql-perl"
# PostgreSQL dependencies
pkg="$pkg libdbd-pg-perl"

## Visualization node
# Build dependencies
PKG="$PKG gcc make tar python-docutils"
# Common dependencies
PKG="$PKG perl perl-base ruby libgd-ruby1.8 libdbi-perl libtie-ixhash-perl libappconfig-perl libsort-naturally-perl libapache2-mod-php5"
# MySQL dependencies
PKG="$PKG libdbd-mysql-perl libdbd-mysql-ruby php5-mysql"
# PostgreSQL dependencies
PKG="$PKG libdbd-pg-perl libdbd-pg-ruby php5-pgsql"

## Ocaml scheduler
PKG="$PKG libpostgresql-ocaml libpostgresql-ocaml-dev libmysql-ocaml libmysql-ocaml-dev ocaml-findlib ocaml-nox libounit-ocaml-dev"

apt-get install $PKG

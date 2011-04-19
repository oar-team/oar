#!/usr/bin/perl
# $Id$
# Check if the database connection is ok
# Return exit status >0 otherwise

use strict;
use warnings;
use DBI();
use oar_iolib;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);

if (defined(iolib::connect_ro_one_log("log"))) {exit 0;}
else{exit 1;}


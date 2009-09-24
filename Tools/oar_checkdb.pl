#!/usr/bin/perl
# $Id$
# Check if the database connection is ok
# Return exit status >0 otherwise

use strict;
use warnings;
use DBI();
use oar_iolib;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);
use oar_Judas qw(set_current_log_category);

set_current_log_category("all");

if (defined(iolib::connect_ro_one())) {exit 0;}
else{exit 1;}


#!/usr/bin/perl
# $Id$
#
# Cleans stagein cache up

use strict;
use DBI();
use oar_iolib;
use oar_conflib qw(init_conf dump_conf get_conf is_conf);

my $base;
init_conf($ENV{OARCONFFILE});
my $stageindir = get_conf("STAGEIN_DIR");
my $expiry = get_conf("STAGEIN_CACHE_EXPIRY");

$base = iolib::connect();
opendir DIR, "$stageindir/" or die "Can't open $stageindir: $!";
while( defined (my $file = readdir DIR) ) {
    my $md5sum = $file;
    iolib::get_lock($base,$md5sum,3600) or die "Failed to lock stagein\n";
    if (iolib::is_stagein_deprecated($base,$md5sum,$expiry) == 1) {
        print "Stagein file \"$file\" is deprecated, removing.\n";
        unlink "$stageindir/$file" or die "Delete failed: $?\n";
        iolib::del_stagein($base,$md5sum);
    }
    iolib::release_lock($base,$md5sum) or die "Failed to unlock stagein\n";
}
close DIR;
iolib::disconnect($base);

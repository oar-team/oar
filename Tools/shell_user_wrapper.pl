#!/usr/bin/perl
# This script can be used as a wrapper just before to call the right user
# shell.

###############################################################################
# You can make some things just before to launch the user shell #
# Here, you are the user                                        #
#################################################################

umask(oct(702));

###############################################################################

my $shell = shift(@ARGV);

if (!defined($ARGV[0])){
    # This is a login shell
    #print "LOGIN SHELL\n";
    my @tmp = split('/',$shell);
    exec({$shell} "-$tmp[$#tmp]");
}else{
    #print "CMD SHELL\n";
    exec($shell,@ARGV);
}


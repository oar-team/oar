#!/usr/bin/perl


###############################################################################
# You can make some thing just before to launch the user shell #
# Here, you are the user                                       #
################################################################

umask("0002");

###############################################################################

my $shell = shift(@ARGV);

if (!defined($ARGV[0])){
    # This is a login shell
    print "LOGIN SHELL\n";
    my @tmp = split('/',$shell);
    exec({$shell} "-$tmp[$#tmp]");
}else{
    print "CMD SHELL\n";
    exec($shell,@ARGV);
}


package oar_Tools;

use strict;

# return a hashtable of child arrays
sub getAllProcessChilds(){
    my %processHash;
    open(CMD, "ps -e -o pid,ppid |");
    while (<CMD>){
        chomp($_);
        $_ =~ /(\d+)\s+(\d+)/;
        if (defined($1) && defined($2)){
            if (!defined($processHash{$2})){
                $processHash{$2} = [$1];
            }else{
                push(@{$processHash{$2}}, $1);
            }
        }
    }
    close(CMD);

    return(%processHash);
}

# return an array of childs
sub getOneProcessChilds($){
    my $oneFather = shift;

    my %processHash = getAllProcessChilds();
    my @childPids;
    my @potentialFather;
    while (defined($oneFather)){
        push(@childPids, $oneFather);
        #Get childs of this process
        foreach my $i (@{$processHash{$oneFather}}){
            push(@potentialFather, $i);
        }
        $oneFather = shift(@potentialFather);
    }

    return(@childPids);
}

return 1;

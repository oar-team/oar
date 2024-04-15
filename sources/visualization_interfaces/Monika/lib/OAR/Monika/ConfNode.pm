## this package handles a node description got from the configuration file
package OAR::Monika::ConfNode;

use strict;
use warnings;
use utf8::all;
use OAR::Monika::monikaCGI qw(-uft8);

## class constructor
sub new {
    my $proto = shift;
    my $class = ref($proto) || $proto;
    my $self  = {};
    $self->{NAME}  = shift;
    $self->{STATE} = shift;
    bless($self, $class);
    return $self;
}

## return node number
sub name {
    my $self = shift;
    return $self->{NAME};
}

## extract the name to display on the page
sub displayHTMLname {
    my $self = shift;
    $self->name() =~ OAR::Monika::Conf::myself()->nodenameRegexDisplay();
    my $shortname = $1 or die "Fail to extract node' shortname";
    return $shortname;
}

## return node state as define in the configuration file.
sub state {
    my $self = shift;
    return $self->{STATE};
}

## print this node status HTML table
sub htmlTable {
    my $self   = shift;
    my $cgi    = shift;
    my $output = "";
    $output .= $cgi->start_table(
        {   -border      => "1",
            -cellspacing => "0",
            -cellpadding => "0",
            -width       => "100%" });
    $output .= $cgi->start_Tr({ -align => "center" });
    $output .= $cgi->colorTd($self->state());
    $output .= $cgi->end_Tr();
    $output .= $cgi->end_table();
    return $output;
}

sub htmlStatusTable {
    my $self   = shift;
    my $cgi    = shift;
    my $output = "";
    $output .= $cgi->start_table(
        {   -border => "1",
            -align  => "center" });
    $output .= $cgi->start_Tr();

    $output .= $cgi->th({ -align => "left", bgcolor => "#c0c0c0" }, $cgi->i("Nodename"));
    $output .= $cgi->th({ -align => "left" },                       $self->name());
    $output .= $cgi->end_Tr();

    $output .= $cgi->start_Tr();
    $output .= $cgi->td({ -align => "left", bgcolor => "#c0c0c0" }, $cgi->i("State"));
    $output .= $cgi->td({ -align => "left" }, $self->state());
    $output .= $cgi->end_Tr();

    $output .= $cgi->end_table();
    return $output;
}

## that's all
return 1;


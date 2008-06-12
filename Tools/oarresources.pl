#!/usr/bin/perl
# $Id$
# Simple Perl script to parse, sort and format a job resource properties file
#
use strict;
use warnings;
use Data::Dumper;
use Getopt::Long;

################################################################################
## Global variables (parameters)
my $property;
my $input=$ENV{OAR_RESOURCE_PROPERTIES_FILE};
my $fmt="";
my @output;
my $comma=",";
my $replace="%";
my $list;

################################################################################
## Option parsing
Getopt::Long::Configure ("gnu_getopt");
GetOptions(
  "input-file|i=s" => \$input,
  "output-format|f=s" => \$fmt,
  "output-property|o=s" => \@output,
  "output-array-comma|c=s" => \$comma,
  "output-replace-string|r=s" => \$replace,
  "list-properties|l" => \$list,
  "help|h" => sub {usage(); exit(0);}
);
$property = shift;

################################################################################
## usage()
sub usage() { 
  print <<EOF;
$0 [options] <key property>
Print a job resources with regard to a key property, with a customisable output
Options:
  -o <property>   property to display, this switch can be used several times
  -f <format>     output format
  -r <string>     joker string to replace in the format string
  -c <separator>  separator to use to display lists of values
  -l              list available properties and exit
  -h              print this help
EOF
}

################################################################################
## init_resource()
sub init_resources {
  open(F, "< $input") or die "$!";
  my @T;
  while (<F>) {
    chomp;
    s/ = / => /g;
    push @T,"{ $_ }";
  }
  close F;
  my $res = eval("[".join(',',@T)."];");
  return $res;
}

################################################################################
## list_properties()
sub list_properties {
  my $resources=shift;
  print "List of properties:\n";
  print join(", ",(keys %{$resources->[0]}))."\n";
}

################################################################################
## print_output()
sub print_output {
  my $resources=shift;
  my $property=shift;
  # build a hash tree sorted on unique values of the key property
  my $h = {}; 
  foreach my $r (@$resources) {;
    exists ($r->{$property}) or die "Unknown property: $property\n";
    my $v = $r->{$property};
    for my $o (@output) {
      exists ($r->{$o}) or die "Unknown property: $o\n";
      $h->{$v}->{$o}->{$r->{$o}} = undef; 
    }
  }
  #print Dumper($h)."\n";

  #print data using the specified format
  foreach my $v (values %$h) {
    my @f = split($replace,$fmt);
    foreach my $o (@output) {
      if ($#f < 0) {
        print " ";
      } else {
        print shift(@f);
      }
      print join($comma,keys(%{$v->{$o}}));
    }
    if ($#f >= 0) {
      print shift(@f);
    }
    print "\n";
  }
}

################################################################################
## Main
my $resources = init_resources();
if (defined($list)) {
  list_properties($resources);
} else {
  if (not defined($property)) { usage(); die "Syntax error.\n"};
  if ($#output < 0) { @output = ($property); }
  print_output($resources,$property);
}

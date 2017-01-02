###############################################################################
##  *** ConfLib: ***
##
## - Description:
##   Home brewed module managing configuration file for OAR
##
## - Usage: init_conf(<filename>);
##   Read the first file matching <filename> in
##   . current directory
##   . $OARDIR directory
##   . /etc directory
##
## - Configuration file format:
## A line of the configuration file looks like that:
## > truc = 45 machin chose bidule 23 # any comment
## "truc" is a configuration entry being assigned "45 machin chose bidule 23"
## Anything placed after a dash (#) is ignored i
## (for instance lines begining with a dash are comment lines then ignored)
## Any line not matching the regexp defined below are also ignored
##
## Module must be initialized using init_conf(<filename>), then
## any entry is retrieved using get_conf(<entry>).
## is_conf(<entry>) may be used to check if any entry actually exists.
##
## - Example:
##  > use ConfLib qw(init_conf get_conf is_conf);
##  > init_conf("oar.conf");
##  > print "toto = ".get_conf("toto")."\n" if is_conf("toto");
##
###############################################################################
# $Id$
package OAR::Conf;

use strict;
use warnings;
require Exporter;
our (@ISA,@EXPORT,@EXPORT_OK);
@ISA = qw(Exporter);
@EXPORT_OK = qw(init_conf get_conf is_conf dump_conf get_conf_list reset_conf get_conf_with_default_param set_value);

## the configuration file.
my $file = undef;
## parameters container...
my %params;
## configuration file regexp (one line).
my $regex = qr{^\s*([^#=\s]+)\s*=\s*([^#]*)};

## Initialization of the configuration
# param: configuration file pathname
# Result: 0 if conf was already loaded
#         1 if conf was actually loaded
#         2 if conf was not found
sub init_conf ($){
  # If file already loaded, exit immediately
  (defined $file) and return 0;
  $file = shift;
  (defined $file) or return 2;
  unless ( -r $file ) {
      if ( defined $ENV{OARDIR} and -r $ENV{OARDIR}."/".$file ) {
          $file = $ENV{OARDIR}."/".$file;
      } elsif ( -r "/etc/".$file ) {
          $file = "/etc/".$file;
      } else {
          warn "Configuration file not found.";
          $file = undef;
          return 2;
      }
  }
  open CONF, $file or die "Open configuration file";
  %params = ();
  foreach my $line (<CONF>) {
    if ($line =~ $regex) {
      my ($key,$val) = ($1,$2);
      $val =~ /^([\"\']?)(.+)\1\s*$/;
      $val = $2 if ($2 ne "");
      $params{$key}=$val;
    }
  }
  close CONF;
  return 1;
}

## get config stored as a Perl hash
## params: config name, hash key to use, default value
## if config is not a hash, return the raw value
## if key is not defined, use _ as the key, otherwise return default value
sub get_conf_from_hash_with_default_value($$$) {
    my $setting = shift;
    my $key = shift;
    my $default = shift;
    my $rawvalue = get_conf_with_default_param($setting, $default);
    if ($rawvalue =~ /^{.*}$/) {
        my $hash = eval($rawvalue);
        if (exists($hash->{$key})) {
            return $hash->{$key};
        } elsif (exists($hash->{_})) {
            return $hash->{_};
        } else {
            return $default;
        }
    } else {
        return $rawvalue;
    }
}

## retrieve a parameter if exists, set it to the default value otherwise
## params: arg1 param name, arg2 default value
sub get_conf_with_default_param ( $$ ) {
    my $key = shift;
    my $default = shift;
    (defined $key) or die "missing a key!";
    (defined $default) or die "missing a default value!";
    if(exists $params{$key}){
    	return $params{$key};
    }
    else {return $default;}
}

## retrieve a parameter
sub get_conf ( $ ) {
    my $key = shift;
    (defined $key) or die "missing a key!";
    return $params{$key};
}

## return the list of configured parameters
sub get_conf_list () {
    return (\%params);
}

## check if a parameter is defined
sub is_conf ( $ ) {
    my $key = shift;
    (defined $key) or die "missing a key!";
    return exists $params{$key};
}

## debug: dump parameters
sub dump_conf () {
    print "Config file is: ".$file."\n";
    while (my ($key,$val) = each %params) {
        print " ".$key." = ".$val."\n";
    }
    return 1;
}

## reset the module state
sub reset_conf () {
    $file = undef;
    %params = ();
    return 1;
}

## set value to a parameter
sub set_value ($$){
	my $variable = shift;
	my $value = shift;
	my $new_file_content;

    open CONF, $file or die "Open configuration file";
    %params = ();
    foreach my $line (<CONF>) {
      if ($line =~ $regex) {
        my ($key,$val) = ($1,$2);
        if ($key eq $variable) {
        	$new_file_content .= $key."="."\"$value\""."\n";
        }
        else {
        	$new_file_content .= $key."=".$val;
        }
      }
      else {
      	if (!defined($new_file_content)) {
      		$new_file_content = $line;
      	}
      	else {
      		$new_file_content.= $line;
      	}
      }
    }
    close CONF;
    
    # writing data in the config file
    write_config($new_file_content);

    return 1;
}

## write content in the config file
sub write_config {
	my $config_content = shift;
	open NEW_CONF, ">$file" or die "Open configuration file";
    print NEW_CONF $config_content;
    close NEW_CONF;
}

return 1;

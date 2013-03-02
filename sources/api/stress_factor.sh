#!/bin/bash
# Sample script for stress_factor
# This script should return at least a real value between 0 and 1 that is given by 
# the OAR api for the "GET /stress_factor" URI.
# Warning: this script is run by root and the output is parsed as a list of
# variables as is!
# - A stress_factor of 0 means that everything is fine
# - A stress_factor of 1 (or more) means that the resources manager is under
# stress. That generally means that it doesn't want to manage anymore jobs!
# - Any value between 0 and 1 is allowed to define the level of stress.
# It allows the administrator to define custom criterias to tell other systems
# (those using the API) that they maybe should reduce or stop to query this
# OAR system for a while. So, this script is meant to be polled regularly.
# The script should return at least the variable "GLOBAL_STRESS=" but it
# may also provide other custom defined values.

# Load the OAR configuration 
. /etc/oar/oar.conf

# By default, returns the load of the OAR server or 1 if could not get it
global_stress=`(su - oar -c "$OPENSSH_CMD $SERVER_HOSTNAME cat /proc/loadavg" 2>/dev/null|| echo 1)| cut -f 1 -d" "`
echo -n "GLOBAL_STRESS="
echo $global_stress


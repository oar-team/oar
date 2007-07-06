#!/bin/bash
# $Id$

# OARSH and SSH hosts REGEXs
OARSH_HOSTS_INCLUDE_FILE=~/.oarsh-hosts-include
OARSH_HOSTS_EXCLUDE_FILE=~/.oarsh-hosts-exclude
# SSH command location
SSHCMD=/usr/bin/ssh
# OAR variables
OARDIR=/usr/lib/oar
OARUSER=oar
OARCMD=oarsh

# unset bash glob expension 
set -f

# Parse SSH options (must be called twice, see below parse_args)
# Be carefull: watch openssh ssh.c source file for new options...
parse_opts() {
	OPTIND=
	while getopts "1246ab:c:e:fgi:kl:m:no:p:qstvxACD:F:I:L:MNO:PR:S:TVw:XY" OPT; do
		case $OPT in
			1 | 2 | 4 | 6 | n | f | x | X | Y | g | P | a | A | k | t | v | V | q | M | s | T | N | C )
				SSHARGS_OPT[$((SSHARGS_OPTCOUNT++))]="-$OPT"
				;;
			O | i | I | w | e | c | m | p | l | L | R | D | o | S | b | F )
				SSHARGS_OPT[$((SSHARGS_OPTCOUNT++))]="-$OPT $OPTARG"
				;;
			* ) 
				SSHARGS_ERROR=255
				;;
		esac
	done
}

# Parse the SSH command args
# Syntax is `ssh [opts] [user@]<host> [opts] [command]'
parse_args() {
	unset SSHARGS_OPT
	SSHARGS_ERROR=0
	SSHARGS_OPTCOUNT=0
	parse_opts $@
	shift $((OPTIND-1))
	SSHARGS_HOST="${1/#*@/}"
	[ -n "$SSHARGS_HOST" ] || SSHARGS_ERROR=255
	SSHARGS_USER="${1/%$SSHARGS_HOST/}"
	SSHARGS_USER="${SSHARGS_USER/%@/}"
	shift 1
	parse_opts $@
	shift $((OPTIND-1))
	SSHARGS_COMMAND="$@"
}

# Debug function: dump parsed information
dump() {
	echo $SSHARGS_OPTCOUNT
	for ((i=0;i<$SSHARGS_OPTCOUNT;i++)); do
		echo "SSHARGS_OPT[$i]="${SSHARGS_OPT[$i]}
	done
	echo "SSHARGS_OPTCOUNT="$SSHARGS_OPTCOUNT
	echo "SSHARGS_HOST="$SSHARGS_HOST
	echo "SSHARGS_USER="$SSHARGS_USER
	echo "SSHARGS_COMMAND="$SSHARGS_COMMAND
	echo "SSHARGS_ERROR="$SSHARGS_ERROR
}

# Check whether SSH or OARSH must be run depending on the hostname.
# First check if host is in the include list, if yes run OARSH.
# Else check if host is in the exclude list, if yes run SSH.
# Else run OARSH.
is_do_ssh_host() {
	if [ -n "$SSHARGS_ERROR" -a $SSHARGS_ERROR -eq 0 -a -n "$SSHARGS_HOST" ]; then
		if [ -r $OARSH_HOSTS_INCLUDE_FILE ]; then
			for h in $(< $OARSH_HOSTS_INCLUDE_FILE); do
				if [[ $SSHARGS_HOST =~ $h ]]; then
					return 1
				fi
			done
		fi
		if [ -r $OARSH_HOSTS_EXCLUDE_FILE ]; then
			for h in $(< $OARSH_HOSTS_EXCLUDE_FILE); do
				if [[ $SSHARGS_HOST =~ $h ]]; then
					return 0
				fi
			done
		fi
		return 1
	fi
	return 0
}

# Remove the -l ssh option for calls of OARSH.
fix_opts() {
	OPTS=
	for ((i=0;i<$SSHARGS_OPTCOUNT;i++)); do
		if [[ ${SSHARGS_OPT[$i]} =~ "^-l" ]]; then
			:
    elif [[ ${SSHARGS_OPT[$i]} =~ "^-i" ]]; then
			export OAR_JOB_KEY_FILE=${SSHARGS_OPT[$i]/#-i /}
		else
			OPTS="$OPTS ${SSHARGS_OPT[$i]}"
		fi
	done
}

# Main program

# Parse args (the $@ var of the main program stays unchanged)
parse_args $@
# check if SSH or OARSH must be called depending on the host
if is_do_ssh_host; then
	exec $SSH_CMD "$@"
fi

# Remove the -l option and fix -i key options
fix_opts
# Sudowrapper mechanism to call oarsh
exec sudo -H -u $OARUSER $OARDIR/cmds/oarsh $OPTS $SSHARGS_HOST "$SSHARGS_COMMAND"
echo "OARSH wrapper failed." 1>&2
exit 11

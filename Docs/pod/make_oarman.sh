#!/bin/sh
# $Id: make_oarman.sh,v 1.3 2004/08/24 16:10:34 neyron Exp $
#
# Generate man pages from Pod files to ../Docs/man directory.
# Argument : release version oar-x.y
#
for i in `ls *.pod | sed -ne 's/.pod//p'`; do
	echo "pod2man $i"
	pod2man --section=1 --release=$1 --center "OAR commands" --name $i "$i.pod" > ../man/$i.1

done


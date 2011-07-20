#!/bin/bash
# $Id: make_man.sh,v 1.1.1.1 2005/01/20 15:21:26 capitn Exp $
#
# Generate man pages from Pod files to ../Docs/man directory.
# Argument : release version oar-x.y
#
for i in `ls *.pod | sed -ne 's/.pod//p'`; do
	echo "pod2man $i"
	pod2man --section=1 --release=1 --center "OAR_GRID commands" --name $i "$i.pod" > $i.1

done


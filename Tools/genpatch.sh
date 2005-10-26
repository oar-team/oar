#!/bin/bash

cvs -d :ext:cvs-id:/home/cvs co -d oar oar
cvs -d :ext:cvs-id:/home/cvs co -d oar-dc -r desktop_computing_branch oar
find -type d -name CVS -exec rm -rf {} \;
find -type f -exec perl -i -pe 's/\$Id: genpatch.sh,v 1.2 2004/12/15 10:24:26 neyron Exp $/' {} \;
diff -Naur oar-dc oar > patch

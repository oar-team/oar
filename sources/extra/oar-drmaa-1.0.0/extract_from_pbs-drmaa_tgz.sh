#!/bin/bash


PBS_DRMAA=pbs-drmaa-1.0.6
for i in m4 drmaa_utils autogen.sh
 do FILES_TO_EXTRACT=$FILES_TO_EXTRACT" "$PBS_DRMAA/$i
done
tar -zxvf $PBS_DRMAA.tar.gz $FILES_TO_EXTRACT
mv $PBS_DRMAA/* .
rm -rf $PBS_DRMAA

# rm -rf m4 drmaa_utils autogen.sh config.h.in autom4te.cache scripts

#rm -rf m4 drmaa_utils autogen.sh config.h.in autom4te.cache scripts config.h config.log stamp-h1 Makefile.in Makefile libtool configure config.status aclocal.m4



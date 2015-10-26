#!/bin/bash
# Script to extract files from OAR deb packages, for later use by push.sh
# Usage: ./extract.sh <debdir> <version> <targetdir>
#   debdir: directory storing debian packages to extract files from
#   version: OAR version of the packages to handle
#   targetdir: directory to store the extracted files

### Handle commandline
DEBDIR=$1
if ! [ -n "$DEBDIR" -a -d "$DEBDIR" ]; then
  echo "Need a directory where to find the deb packages" 1>&2
  exit 1
fi
VERSION=$2
if ! [ -n "$VERSION" ]; then
  echo "Need a OAR version" 1>&2
  exit 1
fi
TARGETDIR=$VERSION

### Main
for f in $DEBDIR/*$VERSION*.deb; do
  p=${f##*/}
  n=${p%%_*}
  echo -n "Extracting files for $n... "
#  if [ "$n" == "oar-doc" -o "${n##*-}" == "mysql" ]; then
#    echo "skipped"
#    continue
#  fi
  echo "done"
  mkdir -p $TARGETDIR
  dpkg-deb -x $f $TARGETDIR/$n
done

for f in $(find $TARGETDIR -exec file {} \; | grep "ELF 64-bit LSB executable" | cut -f1 -d:); do
  rm -v $f ;
done
rm -vrf $TARGETDIR/*/usr/share/doc
rm -vrf $TARGETDIR/*/usr/share/doc-base
rm -vrf $TARGETDIR/*/usr/share/lintian
rm -vrf $TARGETDIR/*/usr/share/man
rm -vrf $TARGETDIR/*/usr/share/oar
rm -vrf $TARGETDIR/*/etc
rm -vrf $TARGETDIR/*/var
rm -vrf $TARGETDIR/oar-server/usr/lib/oar/database

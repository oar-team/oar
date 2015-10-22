#!/bin/bash
if [ "$1" == "-n" ]; then
  DRYRUN=1
  shift;
fi
if [ "$USER" != "root" ]; then
  echo "Need to run as root" 1>&2
  exit 1
fi
  
SRCDIR=$1
shift
if ! [ -n "$SRCDIR" -a -d "$SRCDIR" ]; then
  echo "Need a directory where to find the extracted files" 1>&2
  exit 1
fi
TARGETDIR=$1
shift
if ! [ -n "$TARGETDIR" -a -d "$TARGETDIR" ]; then
  echo "Need a directory where to push the files" 1>&2
  exit 1
fi
if [ -n "$1" ]; then
  INSTALLED_PACKAGES="$@"
else
  INSTALLED_PACKAGES="$(dpkg -l oar-* liboar* | grep ii | cut -f3 -d\ )"
fi
for p in $INSTALLED_PACKAGES; do 
  if [ -d "$SRCDIR/$p" ]; then
    PACKAGES="$PACKAGES $p"
  else
    echo "Directory for package $p not found, skipped"
  fi
done
error=0
for p in $PACKAGES; do 
  echo "Testing $p..."
  for f in $(cd $SRCDIR/$p && find -type f); do
    ff=$TARGETDIR${f#./}
    if ! [ -e $TARGETDIR$ff ]; then
      echo "$TARGETDIR$ff not found"
      error=1;
    elif ! [ -w $TARGETDIR$ff ]; then
      echo "$TARGETDIR$ff not writable"
      ls -l $TARGETDIR$ff
      error=1
    elif [ $(stat -c "%U.%G" $TARGETDIR$ff) != "root.root" ]; then
      echo "$TARGETDIR$ff is not owner by root.root"
      ls -l $TARGETDIR$ff
      #error=1
    fi
  done
done
if [ $error -gt 0 ]; then
  echo "Failed" 1>&2
  exit 1
fi
CHECKSUMFILE=before.${SRCDIR%/}.$(date +%F_%T).md5sum
BACKUPDIR=backup/$(date +%F_%T)

for p in $PACKAGES; do 
  echo "Pushing $p..."
  for f in $(cd $SRCDIR/$p && find -type f); do
    ff=${f#./}
    md5sum $TARGETDIR$ff >> $CHECKSUMFILE
    if [ -n "$DRYRUN" ]; then
      echo "[DRYRUN] Push $TARGETDIR$ff"
    else
      echo "Push $TARGETDIR$ff"
      mkdir -p $BACKUPDIR/${ff%/*}
      cp -a $TARGETDIR$ff $BACKUPDIR/${ff%/*}
      install -o root -g root $SRCDIR/$p/$ff $TARGETDIR$ff
    fi
  done
done
echo Done

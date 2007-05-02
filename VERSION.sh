#!/bin/bash
# $Id$
# helper script to change oar version

VERSIONFILE=Tools/oarversion.pm
if ! [ -r $VERSIONFILE ]; then
  echo "$VERSIONFILE not found, please go to OAR sources base directory"
  exit 3
fi

OARVERSION=$(grep '^[[:space:]]*my[[:space:]]\+\$OARVersion[[:space:]]*=[[:space:]]*"\([[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\)"[[:space:]]*;.*$' $VERSIONFILE | sed 's/^.*"\([[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\)".*$/\1/');

echo "Current Version is: $OARVERSION"
read -p "New version ? " NEWVERSION
if [ -n "$NEWVERSION" ]; then
  if echo $NEWVERSION | grep -q -e "^[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+$"; then
    read -s -p "Confirm version $NEWVERSION ? [y/N]" -n 1 CONFIRM
    echo
    if [ "x$CONFIRM" != "xY" -a "x$CONFIRM" != "xy" ]; then
      echo "Canceled."
      exit 2
    fi
  else
    echo "Bad version: $NEWVERSION. Aborting."
    exit 1
  fi
else
  echo "Aborted."
  exit 2
fi
echo "Editing $VERSIONFILE..."
sed "s/^\([[:space:]]*my[[:space:]]\+\$OARVersion[[:space:]]*=[[:space:]]*\"\)[[:digit:]]\+\.[[:digit:]]\+\.[[:digit:]]\+\(\"[[:space:]]*;.*\)$/\1${NEWVERSION}\2/" $VERSIONFILE > $VERSIONFILE.new
mv $VERSIONFILE.new $VERSIONFILE
echo "Done."

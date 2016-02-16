#!/bin/bash
#
# Wrapper for using aptly for OAR debian packages handling
#
# Author: Pierre Neyron <pierre.neyron@imag.fr>
# Copyright: Laboratoire d'Informatique de Grenoble
# Licence: GNU General Public License Version 2 or above
#
# To use the handle-incoming action, add the following to the crontab:
#
# @reboot inoticoming --logfile $HOME/logs/inoticoming.log $HOME/incoming/ \
#  --chdir $HOME/incoming/ --stdout-to-log --stderr-to-log --suffix .changes \
#  $HOME/bin/aptly-oar.sh handle-incoming {} \;
# 

#NO_MIRROR_UPDATE=1
NO_REMOVE_INCOMING=1
GPG_KEY="D90D0568"

usage() {
  cat <<EOF
Usage:
  ${0##*/} [action]

Actions:
  manage-debian-mirrors    Create/update mirrors of the official Debian repositories + snaptshots
  create-testing-repos     Create the testing local repositories for the target official Debian distributions
  handle-incoming          Handle incoming packages (dput -> inoticoming)
  help                     Pring this message

EOF

}

ACTION=$1
shift

if [ -z "$ACTION" ]; then
  echo -e "Error: Need an action\n" 1>&2
  usage 1>&2
  exit 1
fi

case $ACTION in
  manage-debian-mirrors)
    for d in wheezy wheezy-backports jessie jessie-backports stretch sid experimental; do
      if aptly mirror -raw=true list 2> /dev/null | grep -q -e "^$d$"; then
        echo "*** Mirror for $d already exists"
        if [ -z "$NO_MIRROR_UPDATE" ]; then
          echo "*** Update $d mirror"
          aptly mirror update $d  
        fi
      else
        echo "*** Creating mirror for $d"
        aptly mirror create -architectures=amd64 -with-sources=true  -dep-follow-source=true -dep-follow-all-variants=true -filter-with-deps=false -filter='$Source (oar)| Name (oar)' $d http://ftp.fr.debian.org/debian $d
        echo "*** Populate $d mirror"
        aptly mirror update $d  
      fi
      src=$(aptly mirror search $d oar 2> /dev/null | tail -n 1)
      version=${src%_source}
      if [ -n "$version" ] && ! aptly snapshot -raw=true list 2> /dev/null | grep -q -e "^${d}_$version$"; then
        echo "*** Create snapshot for $version in $d"
        aptly snapshot create ${d}_$version from mirror $d
        echo "*** Publish snapshot ${d}_$version"
        aptly publish -batch=true -gpg-key=$GPG_KEY -distribution="${d}_$version" snapshot ${d}_$version
      else
        [ -n "$version" ] && echo "*** Snapshot ${d}_$version already exists"
      fi
    done
  ;;
  create-testing-repos)
    for d in wheezy-backports_beta jessie-backports_beta sid_beta sid_alpha; do
      if aptly repo -raw=true list 2> /dev/null | grep -q -e "^${d}$"; then
        echo "*** Repo ${d} already exists"
      else
        echo "*** Create beta repo for $d"
        aptly repo -architectures=amd64 create ${d}
      fi
    done
  ;;
  handle-incoming)
    changesfile=$1
    echo "=== Incoming files detected on $(date) ==="
    if ! [ -n "$changesfile" -a -r "$changesfile" ]; then
      echo "*** Bad changefile $changesfile"
      exit 1
    fi
    distribution_line=$(grep -e "^Distribution:" $changesfile)
    debian_distribution=${distribution_line#*: }
    if [ "$debian_distribution" == "UNRELEASED" ]; then
      distribution=sid_alpha
    elif [ "$debian_distribution" == "unstable" ]; then
      distribution=sid_beta
    else
      distribution=${debian_distribution}_beta
    fi
    if aptly repo -raw=true list 2> /dev/null | grep -q -e "^${distribution}$"; then
      echo "*** Importing packages from $changesfile to ${distribution}"
      sleep 0.2
      aptly repo -repo="${distribution}" ${NO_REMOVE_INCOMING:+-no-remove-files=true} -force-replace=true include $changesfile
    else
      echo "*** Local repository ${distribution} does not exist"
      exit 1
    fi
    if aptly publish -raw=true list 2> /dev/null | grep -q -e "^. ${distribution}$"; then
      echo "*** Publishing ${distribution} (update)"
      aptly publish -force-overwrite=true update "${distribution}"
    else
      echo "*** Publishing ${distribution} (create)"
      aptly publish -batch=true -gpg-key=$GPG_KEY -distribution="${distribution}" repo "${distribution}"
    fi
  ;;
  help)
    usage
    exit 0
  ;;
  *)
    echo -e "Error: Unknown action $ACTION\n" 1>&2
    usage 1>&1
    exit 1
  ;;
esac

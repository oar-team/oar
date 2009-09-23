#!/bin/bash
# $Id: $
# build a package (debian or rpm) using a git-svn repository
set -e

usage() {
  cat <<EOF
$0 [-h] [-s] <deb|rpm|tgz> <branch_name>
Build OAR package from the given branch 
 (ex branch name: 'trunk-work', '2.2-test')
Options:
  -s   snapshot version (for generating a beta or not released)
  -h   print this message and exit
EOF
exit 1
}

check_branch() {
  if [ "`git branch |egrep \" $1\$\"`" = "" ]; then
      echo "Branch $1 not found!"
      echo "Maybe, you gave me the name of a remote branch?"
      echo "You should work into a local branch tracking the corresponding remote one."
      echo "You can create it this way:"
      echo "  cd git"
      echo "  git branch $1-work $1"
      echo "  cd .."
      exit 1
  fi
}

get_oar_version() {
  # Sets up the $OARVersion variable
  VER_CMD=`egrep -o -m 1 "OARVersion = \"(.*)\"" Tools/oarversion.pm |sed "s/ //g"`
  eval $VER_CMD
}

get_snapshot_id() {
  SNAPSHOT_ID=`git log --abbrev-commit --pretty=oneline HEAD^..HEAD |cut -d. -f1`
}

SNAPSHOT=n
while getopts "sh" options; do
  case $options in
    s) SNAPSHOT=y ; shift;;
    *) usage ;;
  esac
done

PACKAGE_TYPE=$1
BRANCH_NAME=$2

if [ -z $BRANCH_NAME ] || [ -z $PACKAGE_TYPE ]; then
    usage
fi

if [ ! -r "git/.git" ]; then
  echo "No git repository found!"
  echo "You must have a git repository of OAR into the ./git directory"
  echo "You can init this local git repository with the following:"
  echo "  # The following action maybe very long!"
  echo "  git svn clone https://scm.gforge.inria.fr/svn/oar --trunk=trunk --branches=branches --tags=tags git"
  echo "  cd git"
  echo "  git branch trunk-work trunk"
  echo "  git branch 2.3-work 2.3"
  echo "  git checkout trunk-work"
  echo "  cd .."
  exit 1
fi

OARPWD=$(pwd)
cd git

if [ "`git status |grep 'working directory clean'`" = "" ]; then
    echo "You have uncommited local changes. check with 'git status'."
    exit 1
fi


#####################
# DEBIAN PACKAGING
#####################

if [ "$PACKAGE_TYPE" = "deb" ]
then

  
  check_branch $BRANCH_NAME

  git branch upstream $BRANCH_NAME 
  git checkout $BRANCH_NAME

  get_oar_version

  #REVISION=$(git-svn info Makefile| grep "^Revision:" | cut -d ' ' -f 2)

  if [ "$SNAPSHOT" == "y" ]; then
    git-dch --since=HEAD^ --snapshot --debian-branch=$BRANCH_NAME
    git-add debian/changelog
    WHAT="snapshot"
  else 
    #git-dch --since=HEAD^ --release --debian-branch=$BRANCH_NAME --new-version=$OARVersion
    git-dch --since=HEAD^ --release --debian-branch=$BRANCH_NAME
    git-add debian/changelog
    WHAT="release"
  fi
  #OARVERSION=`egrep -o -m 1 "\((.*\))" debian/changelog|sed "s/[()]//g"`
  #if [ "$OARVERSION" != "" ]; then
  #  perl -pi -e "s/OARVersion =.*$/OARVersion =\"$OARVERSION\";/" Tools/oarversion.pm
  #  git add Tools/oarversion.pm
  #else
  #  echo "Problem getting the generated version!"
  #  exit 1
  #fi
  git commit -m "New $WHAT automaticaly created by git-build-package.sh"

  git-buildpackage --git-debian-branch=$BRANCH_NAME --git-export-dir=../build-area/ -rfakeroot -us -uc
  git branch -D upstream
  echo 
  echo "Your packages have been built into ./build-area/*$OARVERSION* !"


#####################
# RPM PACKAGING
#####################

elif [ "$PACKAGE_TYPE" = "rpm" ]
then
  mkdir -p ../build-area
  check_branch $BRANCH_NAME
  git checkout $BRANCH_NAME
  get_oar_version
  if [ "$OARVersion" != "" ] ; then
      git archive --format=tar HEAD rpm |tar xvf - -C ../build-area
      mkdir -p ../build-area/rpm/BUILD ../build-area/rpm/RPMS ../build-area/rpm/SRPMS
      git archive --format=tar --prefix=oar-$OARVersion/ HEAD | gzip > "../build-area/rpm/SOURCES/oar-$OARVersion.tar.gz"
      cd ../build-area/rpm
      if [ -f /etc/debian_version ]; then
        echo "WARNING: building under Debian, so removing dependencies!"
        perl -pi -e 's/(BuildRequires.*)/#$1/' SPECS/oar.spec
      fi
      perl -pi -e "s/^%define version .*/%define version $OARVersion/" SPECS/oar.spec
      rpmbuild -ba SPECS/oar.spec
      echo "RPM packages done into build-area/rpm/RPMS"
  else
    echo "Could not get the version from Tools/oarversion.pm!"
    exit 1
  fi

#####################
# TARBALL
#####################

elif [ "$PACKAGE_TYPE" = "tgz" ]
then
  check_branch $BRANCH_NAME
  git checkout $BRANCH_NAME
  get_oar_version
  if [ "$OARVersion" != "" ] ; then
    if [ "$SNAPSHOT" == "y" ]; then
      get_snapshot_id
      OARVersion="$OARVersion~git-$SNAPSHOT_ID"
    fi
    git archive --format=tar --prefix=oar-$OARVersion/ HEAD | gzip >../oar-$OARVersion.tar.gz
    echo "oar-$OARVersion.tar.gz archive created"
  else
    echo "Could not get the version from Tools/oarversion.pm!"
    exit 1
  fi
else
  echo "Unknown $1 package type!"
  exit 1
fi


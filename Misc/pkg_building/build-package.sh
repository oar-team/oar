#!/bin/bash
# build a package (debian) using a git repository
set -e

check_branch() {
    if [ "`git branch |egrep \" $1\$\"`" = "" ]; then
        echo "Branch $1 not found!"
        echo "Maybe, you gave me the name of a remote branch?"
        echo "You should work into a local branch tracking the corresponding remote one."
        echo "You can create it this way:"
        echo "  cd <your repository>"
        echo "  git branch $1-work $1"
        echo "  cd .."
        exit 1
    fi
}

get_oar_version() {
    # Sets up the $OARVersion variable
    perl -e "require '$OAR_VERSION_FILE'; print oarversion::get_version()" | sed -e "s/ .*//"
}

get_snapshot_version() {
    OARVERSION=$(perl -e "require '$OAR_VERSION_FILE'; print oarversion::get_version()" | sed -e "s/ .*//")
    REVISION=$(git log --oneline $OARVERSION..$BRANCH_NAME -- | wc -l)
    SNAPSHOT_ID=`git log --abbrev-commit --pretty=oneline --max-count=1 $BRANCH_NAME |sed 's/ /./'|cut -d. -f1`
    if [ "$BRANCH_NAME" != "2.5" ] && [ "$BRANCH_NAME" != "2.4" ]; then
        PREFIX=${BRANCH_NAME//[^a-zA-Z0-9.]/}
    else
        PREFIX=dev
    fi
        echo "${OARVERSION}+${PREFIX}${REVISION}.${SNAPSHOT_ID}"
}

usage() {
  cat <<EOF
  $0 [-h] -q -s|-r|-m tgz|deb|rpm|all <branch_name> [ <debian_branch_name> | <rpm_branch_name>]
Build OAR tarball from the given branch 
 (ex branch name: 'trunk-work', '2.2-test')
Options:
  -s   snapshot version (for generating a beta or not released)
  -r   release version (for publishing)
  -m   merge only (only for debian)
  -h   print this message and exit
  -q   quiet (only write relevant information for automation to stdout)
EOF
exit 1
}

log_info() {
    if [ "$QUIET" != "yes" ]; then
        echo "$*"
    fi
}

gen_tarball() {
    #####################
    # TARBALL
    #####################
    TMPDIR=$(mktemp -d /tmp/oar-tarball.XXXXXX)
    git archive --format=tar --prefix=oar/ $BRANCH_NAME | tar x -C $TMPDIR
    OARVERSION=$(get_oar_version)
    if [ "$ACTION" = "snapshot" ]; then
        VERSION=$(get_snapshot_version)
        sed -e "s/$OARVERSION/$VERSION/" -i $TMPDIR/oar/$OAR_VERSION_FILE
    else 
        VERSION=$OARVERSION
    fi
    if [ -z "$VERSION" ]; then
        echo "An error occuring when retrieving the oar version. Version is empty."
        exit 1
    fi
    cd $OARPWD
    mv $TMPDIR/oar $TMPDIR/oar-$VERSION
    BUILD_AREA=$OARPWD/../build-area/$VERSION
    if [ -e "$BUILD_AREA" ]; then
        log_info "The build area $BUILD_AREA exist. Cleaning..."
        rm -rf $BUILD_AREA
    fi
    mkdir -p $BUILD_AREA
    TARBALL=$BUILD_AREA/oar-$VERSION.tar.gz
    tar czf $TARBALL -C $TMPDIR .
    [ -d "$TMPDIR" ] && rm -rf "$TMPDIR"
    echo "$BUILD_AREA/oar-$VERSION.tar.gz"
}

gen_deb() {
    current_branch=$(git status | head -n 1 | sed -e "s/.* //")
    if [ "$current_branch" != "$DEBIAN_BRANCH_NAME" ]; then
        echo "you're not on the branch '$DEBIAN_BRANCH_NAME'"
        echo "git chechout $DEBIAN_BRANCH_NAME"
        exit 1
    fi
    git-import-orig $TARBALL
    dch -v $VERSION-0 "Snapshot version $VERSION"
    debcommit -a
    if [ "$ACTION" = "release" ] || [ "$ACTION" = "snapshot" ]; then
        mkdir -p $BUILD_AREA/debian/
        git-buildpackage --git-export-dir=$BUILD_AREA/debian/
        echo "Your packages have been built into $BUILD_AREA/debian"
    fi
}

gen_rpm() {
    mkdir -p $BUILD_AREA/rpm/{BUILD,RPMS,SRPMS}
    git archive --format=tar $RPM_BRANCH_NAME | tar xf - -C $BUILD_AREA
    ln -s $TARBALL $BUILD_AREA/rpm/SOURCES/
    cd $BUILD_AREA/rpm
    if [ -f /etc/debian_version ]; then
        echo "WARNING: building under Debian, so removing dependencies!"
        perl -pi -e 's/(BuildRequires.*)/#$1/' SPECS/oar.spec
    fi
    perl -pi -e "s/^%define version .*/%define version $VERSION/" SPECS/oar.spec
    perl -pi -e "s/^%define release (.*)/%define release 0/" SPECS/oar.spec
    if [ "$ACTION" = "release" ] || [ "$ACTION" = "snapshot" ]; then
        rpmbuild -ba SPECS/oar.spec
        echo "RPM packages done into $BUILD_AREA/rpm/RPMS"
    fi
}

ACTION=
QUIET=no
while getopts "qrshm" options; do
  case $options in
    q) QUIET=yes ;;
    s) ACTION=snapshot ;;
    r) ACTION=release ;;
    m) ACTION=merge-only ;;
    *) usage ;;
  esac
done
shift $(($OPTIND - 1))

if [ -z "$ACTION" ]; then
    usage
fi

TARGET=$1
BRANCH_NAME=$2
PACKAGE_BRANCH_NAME=$3

if [ -z "$BRANCH_NAME" ]; then
    usage
fi

if [ -z "$PACKAGE_BRANCH_NAME" ]; then
    DEBIAN_BRANCH_NAME=debian/$BRANCH_NAME
    RPM_BRANCH_NAME=rpm/$BRANCH_NAME
else
    if [ "$TARGET" = "all" ]; then
        echo "In case of 'all', you can't specify debian_branch_name and/or rpm_branch_name (FIXME)"
        exit 1
    fi
    DEBIAN_BRANCH_NAME=$PACKAGE_BRANCH_NAME
    RPM_BRANCH_NAME=$PACKAGE_BRANCH_NAME
fi

if [ ! -d .git ]; then
  echo "No git repository found in the current directory"
fi 

OARPWD=$(pwd)
mkdir -p ../build-area

if [ "`git status |grep 'working directory clean'`" = "" ]; then
    echo "You have uncommited local changes. check with 'git status'."
    exit 1
fi

CURRENT_BRANCH=$(git status | head -n 1 | sed -e 's/.* //')
git checkout $BRANCH_NAME >/dev/null 2>&1

if [ -f debian/control ]; then
    echo "You seem to use a debian branch as a source branch".
    exit 1;
fi

if [ -d rpm ]; then
    echo "You seem to use a rpm branch as a source branch".
    exit 1
fi

if [ -e tools/oarversion.pm ]; then
    OAR_VERSION_FILE=tools/oarversion.pm
elif [ -e Tools/oarversion.pm ]; then
    OAR_VERSION_FILE=Tools/oarversion.pm
else
    echo "The branch $BRANCH_NAME seems to not be OAR"
    exit 1
fi

case $TARGET in
    tgz)
        check_branch $BRANCH_NAME >/dev/null 2>&1
        gen_tarball
        ;;
    deb)
        check_branch $BRANCH_NAME
        check_branch $DEBIAN_BRANCH_NAME
        gen_tarball
        git checkout $DEBIAN_BRANCH_NAME >/dev/null 2>&1 
        gen_deb
        ;;
    rpm)
        check_branch $BRANCH_NAME
        check_branch $RPM_BRANCH_NAME
        gen_tarball
        #git checkout $RPM_BRANCH_NAME
        gen_rpm
        ;;
    all)
        check_branch $BRANCH_NAME
        check_branch $DEBIAN_BRANCH_NAME
        check_branch $RPM_BRANCH_NAME
        gen_tarball
        git checkout $DEBIAN_BRANCH_NAME >/dev/null 2>&1
        gen_deb
        #git checkout $RPM_BRANCH_NAME
        gen_rpm
        ;;
    *)
        usage
        ;;
esac
git checkout $CURRENT_BRANCH >/dev/null 2>&1


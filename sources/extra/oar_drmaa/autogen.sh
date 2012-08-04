#!/bin/sh

run() {
	echo "running $@"
	eval "$@"
}

rm -rf scripts
mkdir scripts

run aclocal -I m4 | grep -v ^/usr/share/aclocal \
&& run libtoolize --copy --force \
&& run autoheader --warnings=all \
&& run automake --gnu --add-missing --copy --warnings=all \
&& run autoconf --warnings=syntax,cross || exit 1

if [ "$*" ]; then
	args="$*"
elif [ -f config.log ]; then
	args=`grep '\$ *\./configure ' config.log \
			 | sed 's:^ *\$ *\./configure ::;s:--no-create::;s:--no-recursion::' \
			 2>/dev/null`
fi

run ./configure ${args}


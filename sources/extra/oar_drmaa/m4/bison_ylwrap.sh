#!/bin/sh
# ylwrap script especialy crafted for Bison

input="$1"; shift

while true; do
	case "$1" in
		"")  exit 1;;
		--)  shift; break;;
		*)   shift;;
	esac
done

prog="$1"; shift; args=($@)
if [ ${prog} != "bison" ]; then
	cat >&2 <<EOF
 * ERROR: Bison was not found at configuration time while some sources are
 * build by it.  Either install Bison <http://www.gnu.org/software/bison/>
 * or download tarball with generated sources included (than you will
 * not be able to modify .y files).
EOF
	exit 1
fi

real_args=()
for i in ${args[@]}; do
	case "$i" in
		-y)  ;;
		--yacc)  ;;
		*)  real_args=(${real_args[@]} "$i") ;;
	esac
done

echo "${prog} --output=`basename ${input} .y`.c ${real_args[@]} ${input}"
${prog} --output=`basename ${input} .y`.c ${real_args[@]} ${input}



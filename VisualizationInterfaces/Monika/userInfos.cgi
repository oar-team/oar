#!/bin/sh

echo Content-type: text/plain
echo

echo "# id $QUERY_STRING"
id "$QUERY_STRING"
#echo
#echo "# oarstat -u $QUERY_STRING --accounting '2006-03-30, 2008-04-30'"
#oarstat -u "$QUERY_STRING" --accounting '2000-01-01, 2010-12-31'


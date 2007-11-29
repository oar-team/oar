#!/bin/sh

echo Content-type: text/plain
echo

id `echo $1|cut -f1 -d'@'`


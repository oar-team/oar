#!/bin/bash
# Sample script for energy saving (shut-down)

NODES=`cat`

for NODE in $NODES
do
  ssh -p 6667 $NODE oardodo /sbin/halt -p
done


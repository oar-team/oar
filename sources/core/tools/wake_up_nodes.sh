#!/bin/bash
# Sample script for energy saving (wake-up)

IPMI_HOST="admin"
POWER_ON_CMD="cpower --up --quiet"

NODES=`cat`

for NODE in $NODES
do
  /usr/lib/oar/oardodo/oardodo ssh $IPMI_HOST $POWER_ON_CMD $NODE
done


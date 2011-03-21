#!/bin/bash
dnotify -q 0 -r -M src -e sh -c "make && (xpdf -remote pres -reload &)"

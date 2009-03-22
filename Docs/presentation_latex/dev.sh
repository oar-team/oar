#!/bin/sh
xpdf -remote pres OAR2_presentation.pdf &
dnotify -q 0 -r -M src -e sh -c "make && (xpdf -remote pres -reload &)"

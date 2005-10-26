#!/usr/bin/make

all: OAR-DOCUMENTATION_head.rst OAR-DOCUMENTATION_foot.rst ../../../INSTALL
	cat OAR-DOCUMENTATION_head.rst ../../../INSTALL OAR-DOCUMENTATION_foot.rst | rst2html -stg > OAR-DOCUMENTATION.html
foot: OAR-DOCUMENTATION_foot.rst
	cat OAR-DOCUMENTATION_foot.rst | rst2html -stg > OAR-DOCUMENTATION.html

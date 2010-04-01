LIBS=unix str
PACKS=mysql
SOURCES= ../common/interval.ml ../common/helpers.ml ../common/conf.ml types.ml iolib.ml \
         ../common/hierarchy.ml ../simple_cbf_mb_h/simple_cbf_mb_h.ml simple_cbf_mb_h_oar.ml
RESULT=simple_cbf_mb_h_oar


all: debug-code

-include ../common/OCamlMakefile

install:  $(RESULT) 
	cp $(RESULT) /usr/lib/oar/


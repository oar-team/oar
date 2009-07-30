LIBS=unix str
PACKS=mysql
SOURCES= ../simple_cbf_mb_h/interval.ml helpers.ml conf.ml types.ml iolib.ml \
         ../simple_cbf_mb_h/hierarchy.ml ../simple_cbf_mb_h/simple_cbf_mb_h.ml simple_cbf_mb_h_oar.ml
RESULT=simple_cbf_mb_h_oar


all: debug-code

-include OCamlMakefile

install:  $(RESULT) 
	cp $(RESULT) /usr/lib/oar/


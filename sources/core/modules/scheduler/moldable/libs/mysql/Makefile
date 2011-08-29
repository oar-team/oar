OCAMLOPT=ocamlopt -principal
OCAMLC=ocamlc -g
OCAML=ledit ocaml
EXEC=oar_sched_mold
OCAMLDEP=ocamldep
OCAMLPREP=-pp camlp4o
OCAMLFLAGS=
STATICFLAGS=-cclib -static -cclib -lz

LIBS=
LOCALLIBS=
OBJS=

CC=gcc
CFLAGS=-g -O2 -I/usr/lib/ocaml/3.06
GCC=gcc

TARGET=../mysql

PREPROCESSEDOBJS=mysql.cmx
OBJS=mysql.cmx
C_OBJS=$(shell pwd)/mysql_stubs.o

all: mysql.cmxa mysql.cma

mysql.cmxa: $(OBJS) $(C_OBJS)
	$(OCAMLOPT) -a -o $(TARGET).cmxa -cclib -lmysqlclient -cclib -lz $^
mysql.cma:  $(OBJS:.cmx=.cmo) $(C_OBJS)
	$(OCAMLC) -a -o $(TARGET).cma -custom -cclib -lmysqlclient -cclib -lz $^

# opt: $(OBJS)
# 	$(OCAMLOPT) -o $(EXEC).dyn  $(OCAMLFLAGS) $(LIBS) $^

# opt.static: $(OBJS)
# 	$(OCAMLOPT) $(STATICFLAGS) -o $(EXEC)  $(OCAMLFLAGS) $(LIBS) $^


# debug: $(OBJS:.cmx=.cmo)
# 	$(OCAMLC) -o $(EXEC).dbg  $(OCAMLFLAGS) $(LIBS:.cmxa=.cma) $^

# interactive: $(OBJS:.cmx=.cmo)
# 	$(OCAML) $(OCAMLFLAGS) $(LIBS:.cmxa=.cma) $^


%.cmx: %.ml
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<
%.cmo: %.ml
	$(OCAMLC) $(OCAMLFLAGS) -c $<

%.cmi: %.mli
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<

%.d : %.ml %.mli
	@set -e; $(OCAMLDEP) $(OCAMLFLAGS) $^ > $@; \
		[ -s $@ ] || rm -f $@

$(PREPROCESSEDOBJS): %.cmx : %.ml
	$(OCAMLOPT) $(OCAMLFLAGS) $(OCAMLPREP) -c $<

$(PREPROCESSEDOBJS:.cmx=.cmo): %.cmo : %.ml
	$(OCAMLC) $(OCAMLFLAGS) $(OCAMLPREP) -c $<
$(PREPROCESSEDOBJS:.cmx=.d): %.d : %.ml %.mli
	@set -e; $(OCAMLDEP) $(OCAMLFLAGS) $(OCAMLPREP) $^ > $@; \
		[ -s $@ ] || rm -f $@

-include $(OBJS:.cmx=.d)

clean: 
	rm -f *.o *.cmo *.cmx *.cmi *.so *.cma *.cmxa *.a *.d $(TARGET).cmxa $(TARGET).cma

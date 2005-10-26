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

CC=gcc-2.95
CFLAGS=-g -O2 -I/usr/lib/ocaml/3.06
GCC=gcc

TARGET=../calendar

INTERFACES=period.cmi
OBJS=time_Zone.cmx date.cmx printer.cmx  time.cmx calendar.cmx

all: calendar.cmxa calendar.cma

calendar.cmxa: $(OBJS) $(INTERFACES)
	$(OCAMLOPT) -a -o $(TARGET).cmxa $(OBJS)
calendar.cma:  $(OBJS:.cmx=.cmo) $(INTERFACES)
	$(OCAMLC) -a -o $(TARGET).cma $(OBJS:.cmx=.cmo)

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

-include $(OBJS:.cmx=.d)

clean: 
	rm -f *.o *.cmo *.cmx *.cmi *.so *.cma *.cmxa *.a *.d $(TARGET).cmxa $(TARGET).cma

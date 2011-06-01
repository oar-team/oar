OCAMLOPT=ocamlopt -principal
OCAMLC=ocamlc -g
OCAML=ledit ocaml
EXEC=oar_sched_mold
OCAMLDEP=ocamldep
OCAMLPREP=-pp camlp4o
OCAMLFLAGS=-I libs/mysql/ -I libs/calendar
STATICFLAGS=-cclib -static -cclib -lmysqlclient -cclib -lz

LIBS=unix.cmxa 
LOCALLIBSNAMES=mysql calendar
LOCALLIBS=$(foreach l,$(LOCALLIBSNAMES),libs/$(l).cmxa)
OBJS=outils.cmx timeConversion.cmx conf.cmx types.cmx iolib.cmx\
 gantt.cmx dynamic_program.cmx selection.cmx scheduler.cmx main.cmx


PREPROCESSEDOBJS=
CC=gcc-2.95
CFLAGS=-g -O2 -I/usr/lib/ocaml/3.06
GCC=gcc

CAMLLIBDIR=`ocamlfind query unix`
MYSQLLIBDIR=`ocamlfind query mysql`

all: opt opt.static debug

# obj: $(OBJS)
# 	$(OCAMLOPT) -noautolink  -output-obj -o $(EXEC).o  $(OCAMLFLAGS) $(LIBS) $^

# zarb: obj
# 	$(GCC) $(EXEC).o $(CAMLLIBDIR)/*.a $(MYSQLLIBDIR)/libmysql_stubs.a  /usr/lib/libmysqlclient.a -ldl /usr/lib/libz.a /usr/lib/libm.a -o $(EXEC).zarb

opt: $(LOCALLIBS) $(OBJS)
	$(OCAMLOPT) -o $(EXEC).dyn  $(OCAMLFLAGS) $(LIBS) $^

opt.static: $(LOCALLIBS) $(OBJS)
	$(OCAMLOPT) $(STATICFLAGS) -o $(EXEC)  $(OCAMLFLAGS) $(LIBS) $^


debug: $(LOCALLIBS:.cmxa=.cma) $(OBJS:.cmx=.cmo)
	$(OCAMLC) -o $(EXEC).dbg  $(OCAMLFLAGS) $(LIBS:.cmxa=.cma) $^

interactive: $(OBJS:.cmx=.cmo)
	$(OCAML) $(OCAMLFLAGS) $(LIBS:.cmxa=.cma) $^


%.cmxa:
	cd $(@:.cmxa=); make

%.cma:
	cd $(@:.cma=); make

%.cmx: %.ml
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<
%.cmo: %.ml
	$(OCAMLC) $(OCAMLFLAGS) -c $<


$(PREPROCESSEDOBJS): %.cmx : %.ml
	$(OCAMLOPT) $(OCAMLFLAGS) $(OCAMLPREP) -c $<

$(PREPROCESSEDOBJS): %.cmo : %.ml
	$(OCAMLC) $(OCAMLFLAGS) $(OCAMLPREP) -c $<

%.d : %.ml
	@set -e; $(OCAMLDEP) $(OCAMLFLAGS) $< > $@; \
		[ -s $@ ] || rm -f $@

-include $(OBJS:.cmx=.d)

%.cmi: %.mli
	$(OCAMLOPT) $(OCAMLFLAGS) -c $<

clean: 
	rm -f *.o *.cmo *.cmx *.cmi *.so *.cma *.cmxa *.a *.d $(EXEC)*
	for l in $(LOCALLIBSNAMES); do (cd libs/$$l; make clean) done

#
# By default kamelot_mysql is built 
# to obtain  kamelot_postgresql use:
# > make clean POSTGRESQL=true all
#
OCAMLMAKEFILE := ./common/OCamlMakefile

# ocamlfind packages required
#export PACKS = str extlib unix batteries
#export PACKS = str batteries

# make POSTGRESQL=true 
ifdef POSTGRESQL
  PPFLAGS := -DPOSTGRESQL
  THREADS := true
  PACKS   := postgresql
  LIBS := str
  SOURCES := ./common/helpers.ml ./common/conf.ml ./common/interval.ml \
             ./common/types.ml ./common/postgresql_driver.ml iolib.ml \
             ./common/hierarchy.ml scheduling.ml kamelot.ml
  RESULT  := kamelot_postgresql
else
  PACKS   := mysql oUnit
  LIBS    := str
  SOURCES := ./common/helpers.ml ./common/conf.ml ./common/interval.ml \
             ./common/types.ml ./common/mysql_driver.ml iolib.ml \
             ./common/hierarchy.ml scheduling.ml kamelot.ml
  RESULT  := kamelot_mysql
endif

define PROJ_kamelot_ts
  PACKS   := mysql oUnit
  LIBS    := str
  SOURCES := ./common/helpers.ml ./common/conf.ml ./common/interval.ml \
             ./common/types_ts.ml ./common/mysql_driver.ml iolib_ts.ml \
             ./common/hierarchy.ml scheduling_ts.ml kamelot_ts.ml
  RESULT  := kamelot_ts_mysql
endef
export PROJ_kamelot_ts

define PROJ_test_unit
  PACKS = oUnit
  LIBS = str 
  SOURCES = ./common/helpers.ml ./common/interval.ml ./common/conf.ml ./common/types.ml\
            ./common/hierarchy.ml scheduling.ml\
            ./test/test_unit.ml
  RESULT = test_unit
endef

export PROJ_test_unit

ifndef SUBPROJS
#  export SUBPROJS = kamelot test_unit 
#  export SUBPROJS = test_unit
export SUBPROJS = kamelot kamelot_ts
endif

#rm_iolib_build:
#rm -f iolib.cmx 

# Default target to use
all: rm_iolib_build nc

include $(OCAMLMAKEFILE)

# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@

rm_iolib_build:
	rm -f iolib.cmx 
#



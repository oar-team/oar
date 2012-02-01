#
# By default simple_cbf_mb_h_ct_oar_mysql is built 
# to obtain  simple_cbf_mb_h_ct_oar_postgresql use:
# > make POSTGRESQL=true
#
OCAMLMAKEFILE := ../common/OCamlMakefile

# make POSTGRESQL=true 
ifdef POSTGRESQL
  PPFLAGS := -DPOSTGRESQL
  THREADS := true
  PACKS   := postgresql
  LIBS := str
  SOURCES := ../common/interval.ml ../common/helpers.ml ../common/conf.ml\
             types.ml postgresql_driver.ml iolib.ml \
             ../common/hierarchy.ml simple_cbf_mb_h_ct.ml simple_cbf_mb_h_ct_oar.ml
  RESULT  := simple_cbf_mb_h_ct_oar_postgresql
else
  PACKS   := mysql oUnit
  LIBS    := str
  SOURCES := ../common/interval.ml ../common/helpers.ml ../common/conf.ml\
             types.ml mysql_driver.ml iolib.ml \
             ../common/hierarchy.ml simple_cbf_mb_h_ct.ml simple_cbf_mb_h_ct_oar.ml
  RESULT  := simple_cbf_mb_h_ct_oar_mysql
endif

define PROJ_test_unit
  PACKS = oUnit
  LIBS = str 
  SOURCES = ../common/interval.ml ../common/helpers.ml ../common/conf.ml types.ml\
            ../common/hierarchy.ml simple_cbf_mb_h_ct.ml\
            test_unit.ml
  RESULT = test_unit
endef
export PROJ_test_unit

ifndef SUBPROJS
#  export SUBPROJS = simple_cbf_mb_h_ct test_unit 
  export SUBPROJS = test_unit
endif

# Default target to use
all: nc

include $(OCAMLMAKEFILE)

# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@


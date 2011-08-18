#
# Upto now only compilatioin with Mysql is supported (22/03/11)
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
  PACKS   := mysql
  LIBS    := str unix
  SOURCES := ../common/interval.ml ../common/helpers.ml ../common/conf.ml\
             types.ml mysql_driver.ml iolib.ml \
             ../common/hierarchy.ml simple_cbf_mb_h_ct.ml simple_cbf_mb_h_ct_oar.ml
  RESULT  := simple_cbf_mb_h_ct_oar_mysql
endif

# Default target to use
all: nc

include $(OCAMLMAKEFILE)

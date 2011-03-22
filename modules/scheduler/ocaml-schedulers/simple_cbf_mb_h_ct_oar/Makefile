#
# Upto now only compilatioin with Mysql is supported (22/03/11)
#
OCAMLMAKEFILE := ../common/OCamlMakefile

# make PPFLAGS=-DPOSTGRESQL or make POSTGRESQL=true
ifdef POSTGRESQL
  PPFLAGS := -DPOSTGRESQL
endif

LIBS := unix str
PACKS := mysql

SOURCES := ../common/interval.ml ../common/helpers.ml ../common/conf.ml types.ml mysql_driver.ml iolib.ml \
          ../common/hierarchy.ml simple_cbf_mb_h_ct.ml simple_cbf_mb_h_ct_oar.ml
RESULT := simple_cbf_mb_h_ct_oar_my

# Default target to use
all: nc

include $(OCAMLMAKEFILE)

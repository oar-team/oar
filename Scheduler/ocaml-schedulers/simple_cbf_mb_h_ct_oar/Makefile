# Set OCamlMakefile to use
export OCAMLMAKEFILE = ../common/OCamlMakefile

# Export some common variable settings

define PROJ_test_iolib_pg
  export LIBS = unix str
  export PACKS = postgresql

  SOURCES=  ../common/helpers.ml ../common/conf.ml ../common/interval.ml types.ml iolib_pg.ml \
          test_iolib_pg.ml
  RESULT= test_iolib_pg
endef
export PROJ_test_iolib_pg

define PROJ_simple_cbf_mb_h_ct_oar_pg
  export LIBS = unix str
  export PACKS = postgresql
  SOURCES= ../common/interval.ml ../common/helpers.ml ../common/conf.ml types.ml postgresql_driver.ml iolib.ml \
           ../common/hierarchy.ml simple_cbf_mb_h_ct.ml simple_cbf_mb_h_ct_oar.ml
  RESULT= simple_cbf_mb_h_ct_oar_pg
endef
export PROJ_simple_cbf_mb_h_ct_oar_pg

define PROJ_simple_cbf_mb_h_ct_oar_my
  export LIBS = unix str
  export PACKS = mysql
  SOURCES= ../common/interval.ml ../common/helpers.ml ../common/conf.ml types.ml mysql_driver.ml iolib.ml \
           ../common/hierarchy.ml simple_cbf_mb_h_ct.ml simple_cbf_mb_h_ct_oar.ml
  RESULT= simple_cbf_mb_h_ct_oar_my
endef
export PROJ_simple_cbf_mb_h_ct_oar_my


# If the environment does not define subprojects to handle,
# then use "ex1 ex2" as default
ifndef SUBPROJS
#  export SUBPROJS = simple_cbf_mb_h_ct_oar_pg 
  export SUBPROJS = simple_cbf_mb_h_ct_oar_my 
endif
 
# Default target to use
#all:	nc
all: bc

pg_driver:
	sed -e s/DBD/Postgresql_driver/g -e 's/NoN\w*//' iolib_tpl.ml > iolib.ml

my_driver:
	sed -e s/DBD/Mysql_driver/g -e 's/NoN\s/not_null\ /g' -e s/NoNStr/not_null\ str2ml/g iolib_tpl.ml > iolib.ml


# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@

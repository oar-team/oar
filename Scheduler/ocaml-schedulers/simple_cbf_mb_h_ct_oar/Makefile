

# Set OCamlMakefile to use
export OCAMLMAKEFILE = ../common/OCamlMakefile

# Export some common variable settings

define PROJ_simple_cbf_mb_h_ct_oar
  export LIBS = unix str
  export PACKS = mysql
  SOURCES= ../common/interval.ml ../common/helpers.ml ../common/conf.ml types.ml iolib.ml \
           ../common/hierarchy.ml simple_cbf_mb_h_ct.ml simple_cbf_mb_h_ct_oar.ml
  RESULT= simple_cbf_mb_h_ct_oar
endef
export PROJ_simple_cbf_mb_h_ct_oar

# If the environment does not define subprojects to handle,
# then use "ex1 ex2" as default
ifndef SUBPROJS
  export SUBPROJS = simple_cbf_mb_h_ct_oar
endif

# Default target to use
#all:	nc
all: bc

# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@

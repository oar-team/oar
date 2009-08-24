

# Set OCamlMakefile to use
export OCAMLMAKEFILE = ../common/OCamlMakefile

# Export some common variable settings

define PROJ_simple_cbf_mb_h_ct
  SOURCES= ../common/interval.ml types.ml ../common/hierarchy.ml simple_cbf_mb_h_ct.ml
  RESULT= simple_cbf_mb_h_ct
endef
export PROJ_simple_cbf_mb_h_ct

define PROJ_test_unit
  export PACKS = oUnit 
  SOURCES = ../common/interval.ml ../common/hierarchy.ml simple_cbf_mb_h.ml test_unit.ml
  RESULT = test_unit
endef
export PROJ_test_unit

define PROJ_test_unit0
  export PACKS = oUnit 
  SOURCES = ../common/interval.ml ../common/hierarchy.ml simple_cbf_mb_h.ml test_unit0.ml
  RESULT = test_unit0
endef
export PROJ_test_unit0

# If the environment does not define subprojects to handle,
# then use "ex1 ex2" as default
ifndef SUBPROJS
#  export SUBPROJS = simple_cbf_mb_h_ct test_unit 
  export SUBPROJS = simple_cbf_mb_h_ct
endif

# Default target to use
#all:	nc
all: bc

# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@

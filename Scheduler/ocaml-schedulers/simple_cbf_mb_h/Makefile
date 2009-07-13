

# Set OCamlMakefile to use
export OCAMLMAKEFILE = ./OCamlMakefile

# Export some common variable settings

define PROJ_simple_cbf_mb_h
  SOURCES= interval.ml types.ml hierarchy.ml simple_cbf_mb_h.ml
  RESULT= simple_cbf_mb_h
endef
export PROJ_simple_cbf_mb_h

define PROJ_test_unit
  export PACKS = oUnit 
  SOURCES = interval.ml hierarchy.ml test_unit.ml
  RESULT = test_unit
endef
export PROJ_test_unit

# If the environment does not define subprojects to handle,
# then use "ex1 ex2" as default
ifndef SUBPROJS
  export SUBPROJS = test_unit
endif

# Default target to use
#all:	nc
all: bc

# Catch-all target will be applied to all subprojects automatically
%:
	@$(MAKE) -f $(OCAMLMAKEFILE) subprojs SUBTARGET=$@

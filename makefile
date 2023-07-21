# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
#  Layout
LIB_DIR := library
SRC_DIR := source
INC_DIR := include
OUT_DIR := output

#  Program
MKDIR := mkdir -p
WGET := wget
RM := rm -f
MV := mv
CC := gcc
TEST := test
SORT := sort
GREP := grep
AWK := awk
PR := pr
SED := sed
LN := ln -s
CAT := cat
TOUCH := touch
BEAR := bear

# Build
SOURCES :=
OBJECTS :=
OUTPUT ?= program
DEPENDENCIES :=

# Internal
.DEFAULT_GOAL = help

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
# $(call get-library-file,library-name)
get-library-file = $(addsuffix .a,$(addprefix $(OUT_DIR)/$(LIB_DIR)/,$1))

# $(call source-to-object,source-list)
source-to-object = $(addprefix $(OUT_DIR)/,$(patsubst %.c,%.o,$1))

# $(call get-library-source,library-name)
get-library-source = $(patsubst %main.c,,									\
					 $(wildcard $(LIB_DIR)/$1/$(SRC_DIR)/*.c))

# $(call get-include-path,from-source)
get-include-path = $(patsubst %$(SRC_DIR)/,%$(INC_DIR)/,$(dir $1))

# $(call make-library, user, name, opt-version)
# e.g. $(call make-library,Cruzer-S,cmacro)
#      https://github.com/Cruzer-S/cmacro
define make-library
$(eval LIB_SRC := $(call get-library-source,$2))
$(eval LIB_OBJ := $(call source-to-object,$(LIB_SRC)))

LIBRARIES += $2

SOURCES += $(LIB_SRC)
OBJECTS += $(LIB_OBJ)

$(call get-library-file,$2): $(LIB_OBJ)
	$(AR) $(ARFLAGS) $$@ $$^

endef

# $(call make-program,name,libraries)
define make-program
$(eval SRC := $(wildcard $(SRC_DIR)/*.c))
$(eval OBJ := $(call source-to-object,$(SRC)))

SOURCES += $(SRC)
OBJECTS += $(OBJ)

OUTPUT := $1

$(OUT_DIR)/$1: $(OBJ) $(call get-library-file,$2)
	$(CC) -o $$@ $$? 

endef

# -----------------------------------------------------------------------------
# Preprocessor
# -----------------------------------------------------------------------------
-include dependencies.mk

$(eval $(call make-program,$(OUTPUT),$(LIBRARIES)))

DEPENDENCIES := $(patsubst %.o,%.d,$(OBJECTS))

create_output_dir := $(shell												\
	$(MKDIR) $(OUT_DIR);													\
	$(MKDIR) $(OUT_DIR)/$(SRC_DIR);											\
	for f in $(sort $(dir $(OBJECTS)));										\
	do																		\
		$(TEST) -d $$f 														\
			|| $(MKDIR) $$f;												\
	done;																	\
	for l in $(LIBRARIES);													\
	do																		\
		$(MKDIR) $(OUT_DIR)/$(LIB_DIR)/$$l/$(SRC_DIR);						\
	done																	\
)

create_include_dir := $(shell												\
	for d in $(LIBRARIES);													\
	do																		\
		$(TEST) -d $(INC_DIR)/$$d ||										\
		$(LN) $(abspath $(LIB_DIR)/$$d/$(INC_DIR))							\
		      $(INC_DIR)/$$d;												\
	done																	\
)

# -----------------------------------------------------------------------------
# Recipes 
# -----------------------------------------------------------------------------
$(OBJECTS): $(OUT_DIR)/%.o: %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $< -o $@ 								\
		  -I$(call get-include-path,$<)

$(DEPENDENCIES): $(OUT_DIR)/%.d: %.c
	# Create dependency files
	@$(CC) $(CFLAGS) -I$(call get-include-path,$<)							\
		   $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $<	| 						\
	$(SED) 's,\($(notdir $*)\.o\) *:,$(dir $@)\1 $@: ,' > $@.tmp
	@$(MV) $@.tmp $@

# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------
.PHONY: build
build: $(OUT_DIR)/$(OUTPUT)

.PHONY: archive
archive: $(LIBRARIES) += $(OUTPUT)

.PHONY: compile
compile: $(OBJECTS)

.PHONY: help
help:
	@$(CAT) $(MAKEFILE_LIST)											|	\
	$(GREP) -v -e '^$$1'												| 	\
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/											\
		   { print substr($$1, 1, length($$1) - 1) }'					|	\
	$(SORT)																|	\
	$(PR) --omit-pagination --width=80 --columns=4

.PHONY: all
all: build

.PHONY: clean
clean:
	$(RM) -r $(OUT_DIR)
	$(RM) $(addprefix $(INC_DIR)/,$(LIBRARIES))

.PHONY: variables
variables:
	# Variables: $(strip $(foreach v,$(.VARIABLES),							\
			$(if $(filter file,$(origin $v)),$v))							\
	)
	$(foreach g,$(MAKECMDGOALS),$(if $(filter-out variables,$g),$g: $($g)))

.PHONY: install
install:

.PHONY: run
run:
	@./$(OUT_DIR)/$(OUTPUT)

.PHONY: 

# -----------------------------------------------------------------------------
# Include
# -----------------------------------------------------------------------------
ifneq "$(MAKECMDGOALS)" "clean"
include $(DEPENDENCIES)
endif

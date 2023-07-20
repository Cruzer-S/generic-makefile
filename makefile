# -------------------------------------------------
# Variables
# -------------------------------------------------
#  Layout
LIB_DIR := libraries
SRC_DIR := sources
INC_DIR := includes
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

# Build 
SOURCES :=
LIBRARIES :=
OBJECTS :=
DEPENDENCIES :=

OUTPUT ?= program

CPPFLAGS += -I$(INC_DIR)
# -------------------------------------------------
# Preprocessor
# -------------------------------------------------
# $(call make-library, user, name, opt-version)
# e.g. $(call make-library,Cruzer-S,cmacro)
#      https://github.com/Cruzer-S/cmacro
define make-library
LIBRARIES += $(LIB_DIR)/$2
endef

# -------------------------------------------------
# Preprocessor
# -------------------------------------------------
# Default target
help:

create_output_dir := $(shell			\
	$(MKDIR) $(OUT_DIR);				\
	$(MKDIR) $(OUT_DIR)/$(SRC_DIR);		\
	for f in $(sort $(dir $(OBJECTS)));	\
	do									\
		$(TEST) -d $$f 					\
			|| $(MKDIR) $$f;			\
	done								\
)

create_include_dir := $(shell						\
	for d in $(LIBRARIES);							\
	do												\
		$(TEST) -d $(INC_DIR)/$$d ||				\
		$(LN) $(abspath $(LIB_DIR)/$$d/includes)	\
		      $(INC_DIR)/$$d;						\
	done											\
)

include dependencies.mk

# -------------------------------------------------
# Targets
# -------------------------------------------------
SOURCES += $(wildcard $(SRC_DIR)/*.c)
OBJECTS += $(addprefix $(OUT_DIR)/,$(patsubst %.c,%.o,$(SOURCES)))
DEPENDENCIES += $(patsubst %.o,%.d,$(OBJECTS))

$(OUT_DIR)/$(OUTPUT): $(OBJECTS)
	$(CC) -o $@ $(OBJECTS)

$(OUT_DIR)/$(OUTPUT).a: $(filter-out %main.o,,$(OBJECTS))
	$(AR) $(ARFLAGS) $@ $^

$(OBJECTS): $(OUT_DIR)/%.o: %.c
	$(CC) -c $(CPPFLAGS) $< -o $@

$(DEPENDENCIES): $(OUT_DIR)/%.d: %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $< | 	\
	$(SED) 's,\($(notdir $*)\.o\) *:,$(dir $@)\1 $@: ,' > $@.tmp
	$(MV) $@.tmp $@

.PHONY: build
build: $(OUT_DIR)/$(OUTPUT)

.PHONY: archive
archive: $(OUT_DIR)/$(OUTPUT).a

.PHONY: compile
compile: $(OBJECTS)

.PHONY: help
help:
	@$(CAT) $(MAKEFILE_LIST)							|	\
	$(GREP) -v -e '^$$1'								| 	\
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/							\
		   { print substr($$1, 1, length($$1) - 1) }'	|	\
	$(SORT)												|	\
	$(PR) --omit-pagination --width=80 --columns=4

.PHONY: all
all: build

.PHONY: clean
clean:
	$(RM) -r $(OUT_DIR)

.PHONY: create
create:
	$(MKDIR) $(SRC_DIR) $(LIB_DIR) $(INC_DIR) $(OUT_DIR)
	$(RM) template.c
	$(WGET) https://raw.githubusercontent.com/Cruzer-S/generic-makefile/main/template.c
	$(MV) template.c $(SRC_DIR)/main.c

.PHONY: variables
variables:
	# Variables: $(strip $(foreach v,$(.VARIABLES),$(if $(filter file,$(origin $v)),$v)))
	$(foreach g,$(MAKECMDGOALS),$(if $(filter-out variables,$g),$g: $($g)))

.PHONY: install
install:

# -------------------------------------------------
# Include
# -------------------------------------------------
ifneq "$(MAKECMDGOALS)" "clean"
include $(DEPENDENCIES)
endif

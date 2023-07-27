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
GIT := git

# Build
SOURCES :=
OBJECTS :=
OUTPUT ?= program
DEPENDENCIES :=
LIBRARIES := $(file < dependencies.mk)

# Internal
.DEFAULT_GOAL = help

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
# $(call get-library-name,library-list) -> library-dir-list
get-library-dir = $(addprefix $(LIB_DIR)/,$1)

# $(call get-library-file,library-list) -> library-file-list
get-library-file = $(addsuffix .a,$(addprefix $(OUT_DIR)/$(LIB_DIR)/,$1))

# $(call get-library-source,library-dir) -> source-list
get-library-source = $(subst $(LIB_DIR)/$1/$(SRC_DIR)/main.c,,$(wildcard $(LIB_DIR)/$1/$(SRC_DIR)/*.c))

# $(call source-to-object,source-list) -> object-list
source-to-object = $(addprefix $(OUT_DIR)/,$(patsubst %.c,%.o,$1))

# $(call get-include-path,from-source) -> include-path
get-include-path = $(patsubst %$(SRC_DIR)/,%$(INC_DIR)/,$(dir $1))

# $(call make-github-library,git-url)
# * git-url: username/repository
define make-github-library

endef

# $(call make-program,name,prerequisite-library)
define make-program
$(eval SRCS := $(wildcard $(SRC_DIR)/*.c))
$(eval OBJS := $(call source-to-object,$(SRCS)))

SOURCES += $(SRCS)
OBJECTS += $(OBJS)

OUTPUT := $1

$(OUT_DIR)/$1: $(OBJS) $(call get-library-file,$2)
	$(CC) -o $$@ $$?

endef

# -----------------------------------------------------------------------------
# Preprocessing
# -----------------------------------------------------------------------------
create_include_dir := $(shell												\
	for d in $(LIBRARIES);													\
	do																		\
		$(TEST) -d $(INC_DIR)/$$(dirname $$d) || 							\
		$(MKDIR) $(INC_DIR)/$$(dirname $$d);								\
		$(TEST) -L $(INC_DIR)/$$d ||										\
		$(LN) ../../$(LIB_DIR)/$$d/$(INC_DIR)								\
		      $(INC_DIR)/$$d;												\
	done																	\
)

$(eval $(call make-github-library,$(LIBRARIES)))
$(eval $(call make-program,$(OUTPUT),$(LIBRARIES)))

# -----------------------------------------------------------------------------
# Recipes 
# -----------------------------------------------------------------------------
.SECONDEXPANSION:
$(call get-library-file,$(LIBRARIES)): $(OUT_DIR)/$(LIB_DIR)/%.a: 			\
		$$(call source-to-object,$$(call get-library-source,%))				\
		| $(call get-library-dir,%)
	$(AR) $(ARFLAGS) $@ $^

$(call get-library-dir,$(LIBRARIES)):
	$(GIT) clone https://github.com/$(patsubst $(LIB_DIR)/%,%,$@) $@

$(OUT_DIR)/%.o: %.c
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
archive: LIBRARIES += $(OUTPUT)

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

# -----------------------------------------------------------------------------
# Include
# -----------------------------------------------------------------------------
ifneq "$(MAKECMDGOALS)" "clean"
include $(DEPENDENCIES)
endif

# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
#  Layout
LIB_DIR := library
SRC_DIR := source
INC_DIR := include
OUT_DIR := output
CNF_DIR := config

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
CTAGS := ctags

# Build
LIBFILE := $(CNF_DIR)/library.mk
RUNFILE := $(CNF_DIR)/run.mk

SOURCES :=
OBJECTS :=
DEPENDENCIES :=

OUTPUT ?= program


LIBRARIES := $(sort $(file < $(LIBFILE)))

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

# $(call create-symlink,base-dir,target-dir,name)
create-symlink = $(shell												\
	$(MKDIR) $1;														\
	$(TEST) -L $(strip $1)/$(strip $3) || 								\
	$(LN) $$(realpath -m --relative-to $1 $2) $(strip $1)/$(strip $3)	\
)

# $(call create-include-dir,base-dir)
create-include-dir = $(foreach d,$(file < $1/$(LIBFILE)),					\
	$(call create-symlink,													\
		$(patsubst %/,%,$1/$(INC_DIR)/$(dir $d)),							\
		$(LIB_DIR)/$d/$(INC_DIR),											\
		$(notdir $d)														\
	)																		\
)

# $(call get-number-of-libraries)
get-number-of-libraries = $(words 											\
	$(foreach u,$(wildcard $(LIB_DIR)/*),$(wildcard $u/*))					\
)

# $(call make-library,name,libraries)
define make-library
$(eval SRC := $(call get-library-source,$1))
$(eval OBJ := $(call source-to-object,$(SRC)))

LIBRARIES += $1

SOURCES += $(SRC)
OBJECTS += $(OBJ)

$(call get-library-file,$1): $(OBJ) $(call get-library-file,$2)
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
	$(CC) -o $$@ $$^

endef
# -----------------------------------------------------------------------------
# Preprocessing
# -----------------------------------------------------------------------------
$(call create-include-dir,.)

$(foreach l,$(LIBRARIES),													\
	$(eval LIBRARIES := $(sort												\
		$(LIBRARIES) $(file < $(LIB_DIR)/$l/$(LIBFILE))						\
	))																		\
)

ifneq "$(words $(LIBRARIES))" "$(call get-number-of-libraries)"

download_libraries := $(foreach l,$(LIBRARIES),								\
	$(shell test -d $(LIB_DIR)/$l 											\
		 || git clone https://github.com/$l $(LIB_DIR)/$l)					\
	$(call create-include-dir,$(LIB_DIR)/$l)								\
)

.PHONY: FORCE
FORCE:

%:: FORCE
	@$(MAKE) $@

else

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

$(foreach l,$(LIBRARIES),													\
	$(eval $(call make-library,$l,											\
			$(file < $(call get-library-dir,$l)/$(LIBFILE))					\
		)																	\
	)																		\
)
$(eval $(call make-program,$(OUTPUT),$(file < $(LIBFILE))))

DEPENDENCIES := $(patsubst %.o,%.d,$(OBJECTS))

# -----------------------------------------------------------------------------
# Recipes 
# -----------------------------------------------------------------------------
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

.PHONY: library
library:
	for l in $(sort $(LIBRARIES));			\
	do										\
		(cd $(LIB_DIR)/$$l; git pull)		\
    done

.PHONY: help
help:
	@$(CAT) $(MAKEFILE_LIST)											|	\
	$(GREP) -v -e '^$$1' -v -e '^FORCE'									| 	\
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/											\
		   { print substr($$1, 1, length($$1) - 1) }'					|	\
	$(SORT)																|	\
	$(PR) --omit-pagination --width=80 --columns=4

.PHONY: tags
tags:
	$(CTAGS) -R

.PHONY: all
all: build

.PHONY: clean
clean:
	$(RM) -r $(OUT_DIR)
	$(RM) -r $(addprefix $(INC_DIR)/,$(dir $(LIBRARIES)))

.PHONY: cleanll
cleanall: clean
	$(RM) -r $(LIB_DIR)

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
	@./$(OUT_DIR)/$(OUTPUT) $(file < $(RUNFILE))

.PHONY: example
example:
	$(MKDIR) $(SRC_DIR) $(INC_DIR) $(LIB_DIR) $(CNF_DIR)
	$(WGET) https://raw.githubusercontent.com/Cruzer-S/generic-makefile/main/main.c
	$(MV) main.c $(SRC_DIR)
# -----------------------------------------------------------------------------
# Include
# -----------------------------------------------------------------------------
ifneq "$(MAKECMDGOALS)" "clean"
ifneq "$(MAKECMDGOALS)" "cleanall"
-include $(DEPENDENCIES)
endif
endif

endif

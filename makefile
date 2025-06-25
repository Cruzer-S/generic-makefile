# -----------------------------------------------------------------------------
# Variables
# -----------------------------------------------------------------------------
# Layout
SRC_DIR := source
INC_DIR := include
CNF_DIR := config
OUT_DIR := output
LIB_DIR := library

# Configure
LIBFILE := $(CNF_DIR)/library.mk
RUNFILE := $(CNF_DIR)/run.mk
BLDFILE := $(CNF_DIR)/build.mk

PIC_FOR_SHARED ?=

# Program
MKDIR := mkdir -p
WGET := wget
RM := rm -f
MV := mv
TEST := test
SORT := sort
GREP := grep
AWK := awk
PR := pr
SED := sed
LN := ln -s
CAT := cat
TOUCH := touch
CTAGS := ctags
CSCOPE := cscope -b
BEAR := bear

# Variable
SOURCES :=
OBJECTS :=
INCLUDES :=
DEPENDENCIES :=

LIBRARIES :=

# Output
OUTPUT := program

CSCOPE_FILE_OUT := cscope.files
CSCOPE_DB_OUT := cscope.out
CTAGS_OUT := tags

COMPILE_DB_OUT := compile_commands.json

# Constants
SYNC_TIME := $(shell LC_ALL=C date)

# Internal
.DEFAULT_GOAL = help

# $(OUTPUT) can be overrided
-include $(BLDFILE)
# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
# $(call loop-pairs,pairs...,func)
first_one = $1
second_one = $2
define loop-pairs
$(if $(word 2,$(1)),														\
	 $(call $(2),$(word 1,$(1)),$(word 2,$(1)))								\
	 $(call loop-pairs,$(wordlist 3,$(words $(1)),$(1)),$(2)))
endef

# $(call get-source-file,dir,ext) -> source-list
get-source-file = $(wildcard $1/$(SRC_DIR)/*$2)

# $(call check-library) -> number of required libraries if zero then empty
check-library =	$(filter-out 												\
	$(wildcard $(LIB_DIR)/*/*),												\
	$(addprefix $(LIB_DIR)/,$(sort											\
		$(foreach f,$(wildcard $(LIB_DIR)/*/*/$(LIBFILE)),					\
			$(call loop-pairs,$(file < $f),first_one)						\
		)																	\
		$(call loop-pairs,$(file < $(LIBFILE)),first_one)					\
	))																		\
)

define __get-library-list
$(if $(filter $2,static),$(addsuffix .a,$1),$(addsuffix .so,$1))
endef

# $(call get-library-file,dir) -> *(.a|.so)-list
define get-library-list
$(call loop-pairs,$(file < $1/$(LIBFILE)),__get-library-list)
endef

# $(call get-include-path,dir) -> include-path-list
define get-include-path
$(addsuffix /$(INC_DIR),$(addprefix $(LIB_DIR)/, 							\
	$(call loop-pairs,$(file < $1/$(LIBFILE)),first_one) 					\
))																			\
$1/$(INC_DIR)
endef

# $(eval $(call make-shared-library,library-dir,output-dir,output))
define make-shared-library
$(eval -include $1/$(BLDFILE))
$(eval override PIC_FOR_SHARED := 1)

$(eval C_SRC := $(patsubst %/main.c,,$(call get-source-file,$1,.c)))
$(eval CXX_SRC := $(patsubst %/main.cpp,,$(call get-source-file,$1,.cpp)))

$(eval C_OBJ := $(addprefix $2/,$(patsubst %.c,%.o,$(C_SRC))))
$(eval CXX_OBJ := $(addprefix $2/,$(patsubst %.cpp,%.o,$(CXX_SRC))))

$(eval C_DEP := $(patsubst %.o,%.d,$(C_OBJ)))
$(eval CXX_DEP := $(patsubst %.o,%.d,$(CXX_OBJ)))

$(eval LIB := $(addprefix $2/$(LIB_DIR)/,$(call get-library-list,$1)))

ifneq ($(strip $(C_SRC) $(CXX_SRC)),)

SOURCES += $(C_SRC) $(CXX_SRC)
OBJECTS += $(C_OBJ) $(CXX_OBJ)
DEPENDENCIES += $(C_DEP) $(CXX_DEP)

$(shell $(MKDIR) $2/$1/$(SRC_DIR))

$(C_OBJ): $2/%.o: %.c
	$(CC) -fPIC $(CFLAGS) $(CPPFLAGS) -c $$< -o $$@ 						\
		  $(addprefix -I,$(call get-include-path,$1))

$(CXX_OBJ): $2/%.o: %.cpp
	$(CXX) -fPIC $(CXXFLAGS) $(CPPFLAGS) -c $$< -o $$@ 						\
		  $(addprefix -I,$(call get-include-path,$1)))

$(C_DEP): $2/%.d: %.c
	@$(CC) -fPIC $(CFLAGS) $(addprefix -I,$(call get-include-path,$1))		\
		   $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	| 						\
		   $(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

$(CXX_DEP): $2/%.d: %.cpp
	@$(CXX) -fPIC $(CXXFLAGS) $(addprefix -I,$(call get-include-path,$1))	\
		   $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	| 						\
		   $(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

$2/$(LIB_DIR)/$3: $(C_OBJ) $(CXX_OBJ) $(LIB)
	$(CXX) -shared -o $$@ $$^ $(LDFLAGS) $(LDLIBS)

else

$2/$(LIB_DIR)/$3:
	$(TOUCH) $$@

endif

$(foreach l,$(call get-library-list,$1),									\
	$(if $(filter $(suffix $l),.a),											\
		$(call make-static-library,$(LIB_DIR)/$(basename $l),$(OUT_DIR),$l),\
		$(call make-shared-library,$(LIB_DIR)/$(basename $l),$(OUT_DIR),$l)	\
	)																		\
)

endef

# $(eval $(call make-static-library,library-dir,output-dir,output))
define make-static-library
$(eval -include $1/$(BLDFILE))

$(eval STATIC_CFLAGS := $(CFLAGS) $(if $(PIC_FOR_SHARED),-fPIC,))
$(eval STATIC_CXXFLAGS := $(CXXFLAGS) $(if $(PIC_FOR_SHARED),-fPIC,))

$(eval C_SRC := $(patsubst %/main.c,,$(call get-source-file,$1,c)))
$(eval CXX_SRC := $(patsubst %/main.cpp,,$(call get-source-file,$1,.cpp)))

$(eval C_OBJ := $(addprefix $2/,$(patsubst %.c,%.o,$(C_SRC))))
$(eval CXX_OBJ := $(addprefix $2/,$(patsubst %.cpp,%.o,$(CXX_SRC))))

$(eval C_DEP := $(patsubst %.o,%.d,$(C_OBJ)))
$(eval CXX_DEP := $(patsubst %.o,%.d,$(CXX_OBJ)))

$(eval LIB := $(addprefix $2/$(LIB_DIR)/,$(call get-library-list,$1)))

ifneq ($(strip $(C_SRC) $(CXX_SRC)),)

SOURCES += $(C_SRC) $(CXX_SRC)
OBJECTS += $(C_OBJ) $(CXX_OBJ)
DEPENDENCIES += $(C_DEP) $(CXX_DEP)

$(shell $(MKDIR) $2/$1/$(SRC_DIR))

$(C_OBJ): $2/%.o: %.c
	$(CC) $(STATIC_CFLAGS) $(CFLAGS) $(CPPFLAGS) -c $$< -o $$@ 				\
		  $(addprefix -I,$(call get-include-path,$1))

$(CXX_OBJ): $2/%.o: %.cpp
	$(CXX) $(STATIC_CXXFLAGS) $(CXXFLAGS) $(CPPFLAGS) -c $$< -o $$@ 		\
		  $(addprefix -I,$(call get-include-path,$1))

$(C_DEP): $2/%.d: %.c
	@$(CC) $(STATIC_CFLAGS) $(CFLAGS) 										\
		   $(addprefix -I,$(call get-include-path,$1))						\
		   $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	| 						\
		   $(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

$(CXX_DEP): $2/%.d: %.cpp
	@$(CXX) $(STATIC_CXXFLAGS) $(CXXFLAGS)									\
			$(addprefix -I,$(call get-include-path,$1))						\
			$(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	|						\
			$(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

$2/$(LIB_DIR)/$3: $(C_OBJ) $(CXX_OBJ) $(LIB)
	$(AR) $(ARFLAGS) $$@ $$^

else

$2/$(LIB_DIR)/$3:
	$(TOUCH) $$@

endif

$(foreach l,$(call get-library-list,$1),									\
	$(if $(filter $(suffix $l),.a),											\
		$(call make-static-library,$(LIB_DIR)/$(basename $l),$(OUT_DIR),$l),\
		$(call make-shared-library,$(LIB_DIR)/$(basename $l),$(OUT_DIR),$l)	\
	)																		\
)

endef

# $(eval $(call make-program,program-dir,out-dir,output))
define make-program
$(eval C_SRC := $(call get-source-file,$1,.c))
$(eval CXX_SRC := $(call get-source-file,$1,.cpp))

$(eval C_OBJ := $(addprefix $2/,$(patsubst %.c,%.o,$(C_SRC))))
$(eval CXX_OBJ := $(addprefix $2/,$(patsubst %.cpp,%.o,$(CXX_SRC))))

$(eval C_DEP := $(patsubst %.o,%.d,$(C_OBJ)))
$(eval CXX_DEP := $(patsubst %.o,%.d,$(CXX_OBJ)))

$(eval LIB := $(addprefix $2/$(LIB_DIR)/,$(call get-library-list,$1)))

SOURCES += $(C_SRC) $(CXX_SRC)
OBJECTS += $(C_OBJ) $(CXX_OBJ)
DEPENDENCIES += $(C_DEP) $(CXX_DEP)

$(shell $(MKDIR) $2/$(SRC_DIR))

$2/%.o: %.c
	$(CC) $(CFLAGS) $(CPPFLAGS) -c $$< -o $$@ 								\
		  $(addprefix -I,$(call get-include-path,$1))

$2/%.o: %.cpp
	$(CXX) $(CXXFLAGS) $(CPPFLAGS) -c $$< -o $$@ 							\
		  $(addprefix -I,$(call get-include-path,$1))

$2/%.d: %.c
	@$(CC) $(CFLAGS) $(addprefix -I,$(call get-include-path,$1))			\
		   $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	| 						\
		   $(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

$2/%.d: %.cpp
	@$(CXX) $(CXXFLAGS) $(addprefix -I,$(call get-include-path,$1))			\
		   $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	| 						\
		   $(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

$2/$3:: $(C_OBJ) $(CXX_OBJ) $(LIB)
	$(CXX) $(LDFLAGS) -o $$@ $$^ $(LDLIBS)

$(foreach l,$(call get-library-list,$1),									\
	$(if $(filter $(suffix $l),.a),											\
		$(call make-static-library,$(LIB_DIR)/$(basename $l),$(OUT_DIR),$l),\
		$(call make-shared-library,$(LIB_DIR)/$(basename $l),$(OUT_DIR),$l)	\
	)																		\
)

endef

# -----------------------------------------------------------------------------
# Preprocessing
# -----------------------------------------------------------------------------
ifneq ($(strip $(call check-library)),)

$(foreach l,$(call check-library),											\
	$(shell git clone --depth=1 											\
					  https://github.com/$(patsubst $(LIB_DIR)/%,%,$l)		\
					  $l													\
	)																		\
)

.PHONY: FORCE
FORCE:

%:: FORCE
	@$(MAKE) $@

else

# -----------------------------------------------------------------------------
# Rules
# -----------------------------------------------------------------------------
$(eval $(call make-program,.,$(OUT_DIR),$(OUTPUT)))
# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------
.PHONY: build
build: $(DEPENDENCIES) $(OUT_DIR)/$(OUTPUT)

.PHONY: compile
compile: $(OBJECTS)

.PHONY: update
update:
	for l in $(sort $(LIBRARIES));											\
	do																		\
		(cd $(LIB_DIR)/$$l; git pull)										\
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
tags: $(SOURCES) $(INCLUDES)
	$(CTAGS) -f $(CTAGS_OUT) $^ 

.PHONY: cscope
cscope: $(SOURCES) $(INCLUDES)
	echo "$(SOURCES) $(INCLUDES)" > $(CSCOPE_FILE_OUT)
	$(CSCOPE) -i $(CSCOPE_FILE_OUT) -f $(CSCOPE_DB_OUT)

.PHONY: bear
bear: clean
	$(BEAR) --output $(COMPILE_DB_OUT) -- $(MAKE) all

.PHONY: all
all: build

.PHONY: clean
clean:
	$(RM) -r $(OUT_DIR)

.PHONY: cleanall
cleanall: clean
	$(RM) -r $(LIB_DIR)
	$(RM) $(CSCOPE_DB_OUT) $(CSCOPE_FILE_OUT) $(CTAGS_OUT) $(COMPILE_DB_OUT)

.PHONY: variables
variables:
	# Variables: $(strip $(foreach v,$(.VARIABLES),							\
			$(if $(filter file,$(origin $v)),$v))							\
	)
	$(foreach g,$(MAKECMDGOALS),$(if $(filter-out variables,$g),$g: $($g)))

.PHONY: install
install:

.PHONY: run
run: $(OUT_DIR)/$(OUTPUT)
	@$(ENVIRONMENTS) ./$(OUT_DIR)/$(OUTPUT) $(ARGUMENTS)

.PHONY: example
example:
	$(MKDIR) $(SRC_DIR) $(INC_DIR) $(LIB_DIR) $(CNF_DIR)
	$(TOUCH) $(DEPFILE) $(RUNFILE)

	$(WGET) https://raw.githubusercontent.com/Cruzer-S/generic-makefile/main/$(SRC_DIR)/main.c
	$(WGET) https://raw.githubusercontent.com/Cruzer-S/generic-makefile/main/$(BLDFILE)

	$(MV) $(notdir $(BLDFILE)) $(CNF_DIR)/
	$(MV) main.c $(SRC_DIR)
# -----------------------------------------------------------------------------
# Include
# -----------------------------------------------------------------------------
ifeq ($(filter clean cleanall bear,$(MAKECMDGOALS)),)
-include $(DEPENDENCIES)
endif

endif

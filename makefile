.SECONDEXPANSION:
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
HEADERS :=
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

-include $(RUNFILE)
# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------
# $(call loop-pairs,pairs...,func)
first_one = $1
second_one = $2
third_one = $3
return_one = $1;$2;$3
define loop-triplet
  $(if $(word 3,$(1)),														\
	   $(call $(2),$(word 1,$(1)),$(word 2,$(1)),$(word 3,$(1)))			\
       $(call loop-triplet,$(wordlist 4,$(words $(1)),$(1)),$(2)))
endef

# $(call get-source-file,dir,ext) -> source-list
get-source-file = $(wildcard $1/$(SRC_DIR)/*$2)
# $(call get-header-file,dir,ext) -> header-list
get-header-file = $(wildcard $1/$(INC_DIR)/*$2)

# $(call check-library) -> number of required libraries if zero then empty
check-library =	$(filter-out 												\
	$(wildcard $(LIB_DIR)/*/*),												\
	$(addprefix $(LIB_DIR)/,$(sort											\
		$(foreach f,$(wildcard $(LIB_DIR)/*/*/$(LIBFILE)),					\
			$(call loop-triplet,$(file < $f),first_one)						\
		)																	\
		$(call loop-triplet,$(file < $(LIBFILE)),first_one)					\
	))																		\
)

LIB_DIRS = $(sort $(dir $1))
LIB_NAMES = $(patsubst lib%.so,%,$(notdir $1))
# $(call LIBFLAGS,libraries) -> (-L<path> -l<name>)-list
LIBFLAGS = $(if $(strip $1),$(addprefix -L,$(call LIB_DIRS,$1)) 			\
		   					$(addprefix -l,$(call LIB_NAMES,$1)))

NAME2LIB = $(addsuffix .so,$(patsubst %$(notdir $1),%lib$(notdir $1),$1))
NAME2ARV = $(addsuffix .a,$1)

# $(call get-library-data,dir) -> (name;type;output)-list
define get-library-data
$(call loop-triplet,$(file < $1/$(LIBFILE)),return_one)
endef

# $(call get-library-list,dir) -> (lib*.so)-list
define get-library-list
$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,shared),$(dir $N)$(call NAME2LIB,$O))					\
))
endef

define get-archive-list
$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,static),$(dir $N)$(call NAME2ARV,$O))					\
))
endef

define loop-library
$(call loop-triplet,$(file < $1/$(LIBFILE)),)
endef

# $(call get-library-path,libraries)
get-library-path = $(foreach l,$(strip $(call LIB_DIRS,$1)),$(abspath $l):)

# $(call get-include-path,dir) -> include-path-list
define get-include-path
$(addsuffix /$(INC_DIR),$(addprefix $(LIB_DIR)/, 							\
	$(call loop-triplet,$(file < $1/$(LIBFILE)),first_one) 					\
))																			\
$1/$(INC_DIR)
endef

# $(call make-XXX,base-dir,out-dir,fPIC,no-main)
define make-XXX
$(eval C_SRC :=	$(if $4,													\
	$(filter-out %/main.c,$(call get-source-file,$1,.c)),					\
	$(call get-source-file,$1,.c)                                           \
))
$(eval CXX_SRC :=	$(if $4,												\
	$(filter-out %/main.cpp,$(call get-source-file,$1,.cpp)),				\
	$(call get-source-file,$1,.cpp)                                         \
))

$(eval C_HDR := $(call get-header-file,$1.h))
$(eval CXX_HDR := $(call get-header-file,$1.hpp))

$(eval C_OBJ := $(addprefix $2/,$(patsubst %.c,%.o,$(C_SRC))))
$(eval CXX_OBJ := $(addprefix $2/,$(patsubst %.cpp,%.o,$(CXX_SRC))))

$(eval C_DEP := $(patsubst %.o,%.d,$(C_OBJ)))
$(eval CXX_DEP := $(patsubst %.o,%.d,$(CXX_OBJ)))

$(eval ARVS := $(addprefix $2/$(LIB_DIR)/,$(call get-archive-list,$1)))
$(eval LIBS := $(addprefix $2/$(LIB_DIR)/,$(call get-library-list,$1)))

$(eval SOURCES += $(C_SRC) $(CXX_SRC))
$(eval HEADERS += $(C_HDR) $(CXX_HDR))
$(eval DEPENDENCIES += $(C_DEP) $(CXX_DEP))

$(shell $(MKDIR) $2/$1/$(SRC_DIR))

$(C_OBJ): $2/%.o: %.c
	$(CC) $(if $3,-fPIC,) $(CFLAGS) $(CPPFLAGS) -c $$< -o $$@ 				\
		  $(addprefix -I,$(call get-include-path,$1))

$(CXX_OBJ): $2/%.o: %.cpp
	$(CXX) $(if $3,-fPIC,) $(CXXFLAGS) $(CPPFLAGS) -c $$< -o $$@ 			\
		  $(addprefix -I,$(call get-include-path,$1))

$(C_DEP): $2/%.d: %.c
	@$(CC) $(if $3,-fPIC,) $(CFLAGS) 										\
		   $(addprefix -I,$(call get-include-path,$1))						\
		   $(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	| 						\
		   $(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

$(CXX_DEP): $2/%.d: %.cpp
	@$(CXX) $(if $3,-fPIC,) $(CXXFLAGS)										\
			$(addprefix -I,$(call get-include-path,$1))						\
			$(CPPFLAGS) $(TARGET_ARCH) -MG -MM $$<	|						\
			$(SED) 's,\($(notdir $$*)\.o\) *:,$(dir $$@)\1 $$@: ,' > $$@.tmp
	@$(MV) $$@.tmp $$@

endef

# $(call make-library,base-dir,output-dir,name,library-out)
define make-library
$(eval -include $1/$(BLDFILE))

$(call make-XXX,$1,$2,fPIC,no-main)

$(eval $4 += $(LIBS))

$(eval $3_ARVS :=)
$(eval $3_LIBS :=)

$2/$(LIB_DIR)/$3: $(C_OBJ) $(CXX_OBJ) $(ARVS) $($3_ARVS) | $(LIBS) $$($3_LIBS)
	$(CXX) $(LDFLAGS) -shared -o $$@ $$^ $$(call LIBFLAGS,$$|) $(LDLIBS)

$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,shared),$(if $(filter undefined,$(origin $O_created)),	\
		$(eval $O_created = shared)											\
		$(call make-library,$(LIB_DIR)/$N,									\
							$2,$(dir $N)$(call NAME2LIB,$O),$3_LIBS)		\
	))																		\
))

$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,static),$(if $(filter undefined,$(origin $O_created)),	\
		$(eval $O_created = static)											\
		$(call make-archive,$(LIB_DIR)/$N,$2,$(dir $N)$(call NAME2ARV,$O),	\
							fPIC,$3_ARVS,$3_LIBS)							\
	))																		\
))

$(eval $4 += $($3_LIBS))

endef

# $(call make-archive,base-dir,out-dir,name,shared,archives-out,libraries-out))
define make-archive
$(eval -include $1/$(BLDFILE))

$(call make-XXX,$1,$2,$(if $4,fPIC),no-main)

ifneq ($(strip $(C_SRC) $(CXX_SRC)),)

$2/$(LIB_DIR)/$3: $(C_OBJ) $(CXX_OBJ)
	$(AR) $(ARFLAGS) $$@ $$^

else

$2/$(LIB_DIR)/$3:
	$(AR) rcs $$@

endif

$(eval $5 += $(ARVS))
$(eval $6 += $(LIBS))

$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,shared),$(if $(filter undefined,$(origin $O_created)),	\
		$(eval $O_created = shared)											\
		$(call make-library,$(LIB_DIR)/$N,									\
							$2,$(dir $N)$(call NAME2LIB,$O),$6)				\
	))																		\
))

$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,static),$(if $(filter undefined,$(origin $O_created)),	\
		$(eval $O_created = static)											\
		$(call make-archive,$(LIB_DIR)/$N,$2,$(dir $N)$(call NAME2ARV,$O),	\
							$4,$5,$6)										\
	))																		\
))

endef

# $(eval $(call make-program,base-dir,out-dir,name,shared,library-out)
define make-program
$(eval override OUTPUT := $3)

$(eval $(call make-XXX,$1,$2,,))

$(eval $4 += $(LIBS))

$(eval $3_ARVS :=)
$(eval $3_LIBS :=)

$2/$3: $(C_OBJ) $(CXX_OBJ) $(ARVS) $$($3_ARVS) | $(LIBS) $$($3_LIBS)
	$(CXX) $(LDFLAGS) -o $$@ $$^ $$(call LIBFLAGS,$$|) $(LDLIBS)

$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,shared),$(if $(filter undefined,$(origin $O_created)),	\
		$(eval $O_created := shared)										\
		$(call make-library,$(LIB_DIR)/$N,									\
							$2,$(dir $N)$(call NAME2LIB,$O),$3_LIBS)		\
	))																		\
))

$(foreach l,$(call get-library-data,$1),$(let N T O,$(subst ;, ,$l),		\
	$(if $(filter $T,static),$(if $(filter undefined,$(origin $O_created)),	\
		$(eval $O_created := static)										\
		$(call make-archive,$(LIB_DIR)/$N,$2,$(dir $N)$(call NAME2ARV,$O),	\
							$(if $4,fPIC),									\
							$3_ARVS,$3_LIBS)								\
	))																		\
))

$(eval $4 += $($3_LIBS))

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
# $(eval $(call make-program,program-dir,output-dir,name)
$(eval $(call make-program,.,$(OUT_DIR),$(OUTPUT),shared,LIBRARIES))
# -----------------------------------------------------------------------------
# Commands
# -----------------------------------------------------------------------------
.PHONY: build
build: $(DEPENDENCIES) $(OUT_DIR)/$(OUTPUT)

.PHONY: help
help:
	@$(CAT) $(MAKEFILE_LIST)											|	\
	$(GREP) -v -e '^$$1' -v -e '^FORCE'									| 	\
	$(AWK) '/^[^.%][-A-Za-z0-9_]*:/											\
		   { print substr($$1, 1, length($$1) - 1) }'					|	\
	$(SORT)																|	\
	$(PR) --omit-pagination --width=80 --columns=4

.PHONY: tags
tags: $(SOURCES) $(HEADERS)
	$(CTAGS) -f $(CTAGS_OUT) $^ 

.PHONY: cscope
cscope: $(SOURCES) $(HEADERS)
	echo "$(SOURCES) $(HEADERS)" > $(CSCOPE_FILE_OUT)
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
run: LD_LIBRARY_PATH:=$(LD_LIBRARY_PATH):$(call get-library-path,$(LIBRARIES))
run: $(OUT_DIR)/$(OUTPUT)
	@LD_LIBRARY_PATH=$(LD_LIBRARY_PATH) $(ENVIRONMENTS) 					\
	./$(OUT_DIR)/$(OUTPUT) $(ARGUMENTS)

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

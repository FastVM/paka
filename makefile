ifdef DC
DC_CMD=$(DC)
else
DC_CMD=dmd
endif

ifdef DC_TYPE
else
ifneq ($(findstring gdc,$(DC_CMD)),)
DC_TYPE_FOUND=gdc
endif
ifneq ($(findstring dmd,$(DC_CMD)),)
DC_TYPE_FOUND=dmd
endif
ifneq ($(findstring ldc,$(DC_CMD)),)
DC_TYPE_FOUND=ldc
endif
DC_TYPE=$(DC_TYPE_FOUND)
endif

DC_TYPE_OK=FALSE
ifeq ($(DC_TYPE),dmd)
DC_TYPE_OK=TRUE
endif
ifeq ($(DC_TYPE),ldc)
DC_TYPE_OK=TRUE
endif
ifeq ($(DC_TYPE),gdc)
$(error The $(DC_TYPE) compiler family cannot compile Dext yet)
endif
ifeq ($(DC_TYPE_OK),FALSE)
$(error Unknown D compiler family $(DC_TYPE), must be in the dmd or ldc family)
endif

ifeq ($(LINK),)
LINK=$(DC_CMD)
endif
LD=$(LINK)

LD_TYPE_FOUND=
ifneq ($(findstring ld,$(LD)),)
LD_TYPE_FOUND=ld
endif
ifneq ($(findstring dc,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring cc,$(LD)),)
LD_TYPE_FOUND=c
endif
ifneq ($(findstring ld.,$(LD)),)
LD_TYPE_FOUND=ld
endif
ifneq ($(findstring dmd,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring gdc,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring ldc,$(LD)),)
LD_TYPE_FOUND=d
endif
ifneq ($(findstring gcc,$(LD)),)
LD_TYPE_FOUND=c
endif
ifneq ($(findstring clang,$(LD)),)
LD_TYPE_FOUND=c
endif

ifdef LD_TYPE
else
LD_TYPE=$(LD_TYPE_FOUND)
endif

LD_CMD=$(LINK)

ifeq ($(LD_TYPE),c)
LFLAGS_EXTRA=-Wl,--export-dynamic
endif

ifeq ($(LD_TYPE),ld)
LFLAGS_EXTRA=-export-dynamic -l:libgcc_s.so.1 -l:crt1.o -lc -l:crti.o -l:crtn.o -dynamic-linker /lib64/ld-linux-x86-64.so.2
endif

ifeq ($(LD_TYPE),d)
ifeq ($(DC_TYPE),ldc)
LD_LINK_IN_CORRECT_STD=-defaultlib= -L-l:libphobos2-ldc-shared.so -L-l:libdruntime-ldc-shared.so
else
LD_LINK_IN_CORRECT_STD=-defaultlib= -L-l:libphobos2.so -L-l:libdruntime-ldc-shared.so
endif
LD_CMD_OUT_FLAG=-of=
LD_LINK_IN=$(patsubst %,-L%,$(LFLAGS)) $(LD_LINK_IN_CORRECT_STD) -L-export-dynamic
LD_LINK_IN_LIBS=$(LD_LINK_IN)
LD_LINK_IN_DEXT=$(LD_LINK_IN) -L-ldl
else
ifeq ($(DC_TYPE),ldc)
LD_LINK_IN_STD=-l:libdruntime-ldc-shared.so -l:libphobos2-ldc-shared.so
else
LD_LINK_IN_STD=-lphobos2
endif
LD_LINK_IN=$(LFLAGS) $(LD_LINK_IN_STD) -lpthread -lm -lrt $(LFLAGS_EXTRA) 
LD_LINK_IN_DEXT=$(LD_LINK_IN) -ldl
LD_CMD_OUT_FLAG=-o
endif

FROM_DIR=$(dir $(realpath $(firstword $(MAKEFILE_LIST))))
OUT_DIR=$(FROM_DIR)/dlang
ifeq ($(shell which $(DC_CMD)),)
ifneq ($(LD_CMD),$(DC_CMD))
$(error Cannot specify linker when using $(DC_CMD) from local path)
endif
ifeq ($(DC_TYPE),dmd)
DC_CMD_PRE=dmd
endif
ifeq ($(DC_TYPE),ldc)
DC_CMD_PRE=ldc2
endif
DC_CMD:=$(OUT_DIR)/$(DC_CMD_PRE).sh
ALL_REQURED+=getcomp
endif

ALL_DO_OPT=UNKNOWN

ifeq ($(OPT),)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif

ifeq ($(OPT),0)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif
ifeq ($(OPT),none)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif
ifeq ($(OPT),false)
ALL_DO_OPT=FALSE
OPT_LEVEL=0
endif

ifeq ($(OPT),1)
ALL_DO_OPT=TRUE
OPT_LEVEL=1
endif

ifeq ($(OPT),2)
ALL_DO_OPT=TRUE
OPT_LEVEL=2
endif

ifeq ($(OPT),3)
ALL_DO_OPT=TRUE
OPT_LEVEL=3
endif
ifeq ($(OPT),full)
ALL_DO_OPT=TRUE
OPT_LEVEL=3
OPT_FULL_FOR_DMD=TRUE
endif
ifeq ($(OPT),true)
ALL_DO_OPT=TRUE
OPT_LEVEL=3
OPT_FULL_FOR_DMD=TRUE
endif
ifeq ($(OPT),all)
ALL_DO_OPT=TRUE
OPT_LEVEL=3
OPT_FULL_FOR_DMD=TRUE
endif

ifeq ($(OPT),s)
ALL_DO_OPT=TRUE
OPT_LEVEL=s
endif

ifeq ($(OPT),small)
ALL_DO_OPT=TRUE
OPT_LEVEL=s
endif

ifeq ($(OPT),size)
ALL_DO_OPT=TRUE
OPT_LEVEL=s
endif

ifdef OPT
ifeq ($(ALL_DO_OPT),UNKNOWN)
$(error $(DC_TYPE) Cannot optimize for: OPT=$(OPT))
endif
endif

ifeq ($(ALL_DO_OPT),TRUE)
ifeq ($(DC_TYPE),dmd)
ifneq ($(OPT_FULL_FOR_DMD),TRUE)
$(error dmd (unlike ldc2) cannot optimize for: OPT=$(OPT))
else
OPT_FLAGS=-O
endif
else
OPT_FLAGS=-O$(OPT_LEVEL)
endif
else
OPT_FLAGS=
endif

DFLAGS=
FULL_DFLAGS=$(DFLAGS)

DLIB=libphobos2.so
ifeq ($(DC_TYPE),dmd)
# DEF_FLAG=-defaultlib=$(DLIB)
DFL_FLAG_DEXT=$(DEF_FLAG)
DFL_FLAG_LIBS=$(DEF_FLAG)
else
DEF_FLAG=
DEF_FLAG_LIBS=-shared $(DEF_FLAG)
DEF_FLAG_DEXT=
endif
LIBS=
EXTRA_LIBS=$(LIBS)
RAW_EXTRA_LIBS=
FULL_RAW_EXTRA_LIBS=$(RAW_EXTRA_LIBS) $(patsubst %,out/lib/libdext_%.so,$(EXTRA_LIBS))

RUN=@
INFO=@echo

ifeq ($(DC_TYPE),dmd)
	REALOCATON_MODE_TO_PIC=-fPIC
else
	REALOCATON_MODE_TO_PIC=-relocation-model=pic
endif

dext: all out/dext/dext
	$(RUN) cp out/dext/dext ./dext

quest: all out/lib/libdext_quest.so

clean-dext: dummy
	$(RUN) rm -rf out/dext/dext dext

clean: dummy
	$(RUN) rm -rf out dext

out/dext/dext: out/dext
	$(INFO) Compiling: out/dext/app.o from source/app.d
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c -i source/app.d -Isource -of=out/dext/app.o
	$(INFO) Linking: out/dext/app.o into out/dext/dext
	$(RUN) $(LD_CMD) $(FULL_DFLAGS) $(LD_CMD_OUT_FLAG)out/dext/dext out/dext/app.o $(LD_LINK_IN_DEXT) $(DFL_FLAG_DEXT)

out/lib/libdext_quest.so: out/lib
	$(INFO) Compiling: out/quest/plugin.o from ext/quest/plugin.d
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c -i ext/quest/plugin.d -Isource -Iext -od=out/quest -of=out/quest/plugin.o
	$(INFO) Linking: out/lib/libdext_quest.so
	$(RUN) $(LD_CMD) $(FULL_DFLAGS) -shared $(LD_CMD_OUT_FLAG)out/lib/libdext_quest.so out/quest/plugin.o $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

INSTALLER=bash $(OUT_DIR)/install.sh
DO_INSTALL=$(DC_CMD)
ENV=\$$

$(DC_CMD): $(OUT_DIR)/install.sh
	$(INFO) Installing D Compiler
	$(RUN) $(INSTALLER) install --path $(OUT_DIR) $(COMPILER) > $(OUT_DIR)/info.sh
	$(RUN) rm -f $(DC_CMD)
	$(RUN) echo "#!/usr/bin/env bash" > $(DC_CMD)
	$(RUN) ($(INSTALLER) get-path --path $(OUT_DIR) $(DC_CMD_PRE) | tr "\n" " "; echo $(ENV)@) >> $(DC_CMD)
	$(RUN) chmod +x $(DC_CMD)

getcomp: $(DO_INSTALL)

$(OUT_DIR)/install.sh:
	$(RUN) mkdir -p $(OUT_DIR)
	$(INFO) Downloading D Compiler
	$(RUN) curl https://dlang.org/install.sh > $(OUT_DIR)/install.sh 2>/dev/null

all: $(ALL_REQURED)

out/lib:
	$(RUN) mkdir -p out/lib

out/dext:
	$(RUN) mkdir -p out/dext

dummy:

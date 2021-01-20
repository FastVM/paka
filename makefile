ifdef DC
DC_CMD=$(DC)
else
DC_CMD=dmd
endif

ifeq ($(DC_TYPE),)
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
DC_TYPE_OK=TRUE
endif
# ifeq ($(DC_TYPE),gdc)
# $(error The $(DC_TYPE) compiler family cannot compile purr yet)
# endif
ifeq ($(DC_TYPE_OK),FALSE)
$(error Unknown D compiler family $(DC_TYPE), must be in the dmd or ldc or gdc family)
endif

ifeq ($(LD),)
LD=$(DC_CMD)
endif

ifeq ($(LD),ld)
LD=ld.gold
endif

ifeq ($(LD),ld.bfd)
$(error cannot use LD=ld.bfd yet)
endif

ifeq ($(LD),gdc)
$(error cannot use LD=gdc yet)
endif

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

ifeq ($(LD_TYPE),)
LD_TYPE=$(LD_TYPE_FOUND)
endif

LD_CMD=$(LD)

ifeq ($(LD_TYPE),d)
ifeq ($(LD_DC_TYPE),)
ifneq ($(findstring gdc,$(LD_CMD)),)
LD_DC_TYPE=gdc
endif
ifneq ($(findstring dmd,$(LD_CMD)),)
LD_DC_TYPE=dmd
endif
ifneq ($(findstring ldc,$(LD_CMD)),)
LD_DC_TYPE=ldc
endif
endif
endif

ifeq ($(LD_TYPE),c)
LFLAGS_EXTRA=-Wl,--export-dynamic
endif

ifeq ($(LD_TYPE),ld)
LFLAGS_EXTRA=-export-dynamic -l:libgcc_s.so.1 -l:crt1.o -lc -l:crti.o -l:crtn.o -dynamic-linker /lib64/ld-linux-x86-64.so.2
endif

ifeq ($(LD_TYPE),d)
ifeq ($(DC_TYPE),dmd)
LFLAGS_DC_SIMPLE= -l:libphobos2.so -l:libdruntime-ldc-shared.so
endif
ifeq ($(DC_TYPE),gdc)
LFLAGS_DC_SIMPLE= -l:libgphobos.so.1 -l:libgdruntime.so.1
endif
ifeq ($(DC_TYPE),ldc)
LFLAGS_DC_SIMPLE= -l:libphobos2-ldc-shared.so -l:libdruntime-ldc-shared.so
endif
LFLAGS_DC=$(LFLAGS_DC_SIMPLE) $(LFLAGS) -ldl
ifeq ($(LD_DC_TYPE),gdc)
LFLAGS_LD=-nophoboslib $(LFLAGS_DC) -lm
LFLAGS_LD_PURR=-ldl
else
LFLAGS_LD=-defaultlib= $(patsubst %,-L%,$(LFLAGS_DC))
LFLAGS_LD_PURR=-L-ldl
endif
LD_LINK_IN= $(LFLAGS_LD) -L-export-dynamic
LD_LINK_IN_LIBS=$(LD_LINK_IN)
LD_LINK_IN_PURR=$(LD_LINK_IN) $(LFLAGS_LD_PURR) 
else
ifeq ($(DC_TYPE),dmd)
LD_LINK_IN_CORRECT_STD=-lphobos2
endif
ifeq ($(DC_TYPE),gdc)
LD_LINK_IN_CORRECT_STD=-l:libgphobos.so.1 -l:libgdruntime.so.1
endif
ifeq ($(DC_TYPE),ldc)
LD_LINK_IN_CORRECT_STD=-l:libdruntime-ldc-shared.so -l:libphobos2-ldc-shared.so
endif
LD_LINK_IN=$(LFLAGS) $(LD_LINK_IN_CORRECT_STD) -lpthread -lm -lrt $(LFLAGS_EXTRA) 
LD_LINK_IN_LIBS=$(LD_LINK_IN)
LD_LINK_IN_PURR=$(LD_LINK_IN) -ldl
endif

ifeq ($(LD_TYPE),d)
ifeq ($(LD_DC_TYPE),gdc)
LD_CMD_OUT_FLAG=-o
else
LD_CMD_OUT_FLAG=-of=
endif
else
LD_CMD_OUT_FLAG=-o
endif

ifeq ($(DC_TYPE),gdc)
DC_CMD_OUT_FLAG=-o
else
DC_CMD_OUT_FLAG=-of=
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
ifeq ($(OPT),dcomp)
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
DFL_FLAG_PURR=$(DEF_FLAG)
DFL_FLAG_LIBS=$(DEF_FLAG)
else
DEF_FLAG=
DEF_FLAG_LIBS=-shared $(DEF_FLAG)
DEF_FLAG_PURR=
endif

RUN=@
INFO=@echo

ifeq ($(DC_TYPE),ldc)
REALOCATON_MODE_TO_PIC=-relocation-model=pic
else
REALOCATON_MODE_TO_PIC=-fPIC
endif

ifeq ($(shell test -e ./$(BIN)/lib/UnicodeData.txt && echo -n yes),yes)
CURL_CMD_FOR=@:
else
CURL_CMDS_NEEDED=$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > ./$(BIN)/lib/UnicodeData.txt
endif

rwildcard=$(foreach d,$(wildcard $(1:=/*)),$(call rwildcard,$d,$2) $(filter $(subst *,%,$2),$d))
ifeq ($(DC_TYPE),gdc)
dlangsrc=$(call rwildcard,$1,*.d)
else
dlangsrc=-i $1/$2
endif

BIN=bin

all: purr paka quest unicode

vm: purr
purr: $(BIN)/purr

$(BIN)/purr: dcomp $(BIN)/purr.o
	$(INFO) Linking: $(BIN)/purr
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purr $(BIN)/purr.o $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR)

$(BIN)/purr.o: $(BIN)
	$(INFO) Compiling: purr/app.d
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,purr,app.d) -Ipurr $(DC_CMD_OUT_FLAG)$(BIN)/purr.o

unicode: libpurr_unicode.so
	$(RUN) cp $(BIN)/lib/libpurr_unicode.so unicode.so

libpurr_unicode.so: dcomp $(BIN)/lib
	$(CURL_CMDS_NEEDED) 
	$(INFO) Compiling: ext/unicode/plugin.d
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/unicode,plugin.d) -Ipurr -Iext -od=$(BIN)/unicode $(DC_CMD_OUT_FLAG)$(BIN)/unicode/plugin.o -J./$(BIN)/lib
	$(INFO) Linking: $(BIN)/lib/libpurr_unicode.so
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$(BIN)/lib/libpurr_unicode.so $(BIN)/unicode/plugin.o $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

quest: dcomp $(BIN)/lib/libpurr_quest.so
	$(RUN) cp $(BIN)/lib/libpurr_quest.so quest.so

$(BIN)/lib/libpurr_quest.so: $(BIN)/lib $(BIN)/quest
	$(INFO) Compiling: ext/quest/plugin.d
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/quest,plugin.d) -Ipurr -Iext -od=$(BIN)/quest $(DC_CMD_OUT_FLAG)$(BIN)/quest/plugin.o
	$(INFO) Linking: $(BIN)/quest/plugin.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$(BIN)/lib/libpurr_quest.so $(BIN)/quest/plugin.o $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

dext: paka
paka: dcomp $(BIN)/lib/libpurr_paka.so
	$(RUN) cp $(BIN)/lib/libpurr_paka.so paka.so

$(BIN)/lib/libpurr_paka.so: $(BIN)/lib $(BIN)/paka
	$(INFO) Compiling: ext/paka/plugin.d
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/paka,plugin.d) -Ipurr -Iext -od=$(BIN)/paka $(DC_CMD_OUT_FLAG)$(BIN)/paka/plugin.o
	$(INFO) Linking: $(BIN)/paka/plugin.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$(BIN)/lib/libpurr_paka.so $(BIN)/paka/plugin.o $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

clean: dummy
	$(RUN) rm -rf $(BIN) quest.so unicode.so

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

dcomp: $(ALL_REQURED)

$(BIN):
	$(RUN) mkdir -p $(BIN)

$(BIN)/lib: $(BIN)
	$(RUN) mkdir -p $(BIN)/lib

$(BIN)/paka: $(BIN)
	$(RUN) mkdir -p $(BIN)/paka

$(BIN)/quest: $(BIN)
	$(RUN) mkdir -p $(BIN)/quest

dummy:

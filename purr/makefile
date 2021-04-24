$(call import,dcomp.mak)
LANG=paka

PURR_DIRS=purr/ast purr/bc purr/data purr/fs purr/ir purr/plugin purr/serial purr
PURR_OBJS=$(patsubst %,$(LIB)/%.o,$(subst /,_,$(PURR_DIRS)))

$(BIN)/purr: $(PURR_OBJS) $(LIBS_THIS) $(BIN)
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purr $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR) $(PURR_OBJS) $(LIBS_THIS)

ifeq ($(PURR_OBJS), $(BIN)/purr.o)
$(BIN)/purr.o: dcomp $(BIN)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) -c $(call dlangsrc,purr) $(DC_CMD_OUT_FLAG)$(BIN)/purr.o -Ipurr $(FULL_DFLAGS)
else
$(PURR_OBJS): $(subst _,/,$(patsubst $(LIB)/%.o,%,$@)) $(LIB)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) -c $(wildcard $(subst _,/,$(patsubst $(LIB)/%.o,%,$@))/*.d) $(DC_CMD_OUT_FLAG)$@ $(FULL_DFLAGS)
endif

FILES=$(shell find ext/rt ext/core ext/passerine ext/paka ext/serial purr -type f | grep \\.d)
debug: $(BIN)
	$(RUN) $(DC_CMD) -g -Iext $(FILES) -od=$(BIN) $(DC_CMD_OUT_FLAG)$(BIN)/purr $(DFLAGS)

ifeq ($(DC_TYPE),gdc)
RELEASE_FLAG=-frelease
else
RELEASE_FLAG=-release
endif

release: $(BIN)
	$(RUN) $(DC_CMD) -Iext $(FILES) -od=$(BIN) $(DC_CMD_OUT_FLAG)$(BIN)/purr -O $(RELEASE_FLAG) $(DFLAGS)
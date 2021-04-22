$(call import,dcomp.mak)
LANG=paka

PURR_DIRS=purr/ast purr/bc purr/data purr/fs purr/ir purr/plugin purr/serial purr
PURR_OBJS=$(patsubst %,$(LIB)/%.o,$(subst /,_,$(PURR_DIRS)))

$(BIN)/purr: $(PURR_OBJS) $(LIBS_THIS) $(BIN)
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purr $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR) $(PURR_OBJS) $(LIBS_THIS)

$(PURR_OBJS): $(subst _,/,$(patsubst $(LIB)/%.o,%,$@)) $(LIB)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(wildcard $(subst _,/,$(patsubst $(LIB)/%.o,%,$@))/*.d) $(DC_CMD_OUT_FLAG)$@

FILES=$(shell find ext/rt ext/passerine ext/paka ext/serial purr -type f | grep \\.d)
debug: $(BIN)
	$(RUN) dmd -g -Iext $(FILES) -od=$(BIN) -of=$(BIN)/purr $(DFLAGS)

release: $(BIN)
	$(RUN) $(DC_CMD) -Iext $(FILES) -od=$(BIN) -of=$(BIN)/purr -O3 -release $(DFLAGS)
$(call import,dcomp.mak)
LANG=paka

$(BIN)/purr: $(BIN)/purr.o $(LIBS_THIS)
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purr $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR) $^

$(BIN)/purr.o: dcomp $(BIN)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,purr,app.d) $(DC_CMD_OUT_FLAG)$(BIN)/purr.o -Ipurr 

DEFAULT_DC=ldc2

FILES=$(shell find ext/rt ext/passerine ext/paka ext/serial purr -type f | grep \\.d)
debug: $(BIN)
	$(RUN) dmd -g -Iext $(FILES) -od=$(BIN) -of=$(BIN)/passerine $(DFLAGS)

release: $(BIN)
	$(RUN) $(DC_CMD) -Iext $(FILES) -od=$(BIN) -of=$(BIN)/passerine -O3 -release $(DFLAGS)
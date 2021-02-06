$(call import,dcomp.mak)

$(BIN)/purr: $(BIN)/purr.o $(LIBS_THIS)
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purr $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR) $(LD_LINK_PURR_LIBS) $^

$(BIN)/purr.o: dcomp $(BIN)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,purr,app.d) $(DC_CMD_OUT_FLAG)$(BIN)/purr.o -Ipurr -Ipurrc -Illvm/source

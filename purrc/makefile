$(call import,dcomp.mak)
$(call import,purr/makefile)

$(BIN)/purrc: $(BIN)/purrc.o $(LIBS_THIS)
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purrc $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR) $(LD_LINK_PURR_LIBS) $^

$(BIN)/purrc.o: dcomp $(BIN) $(TMP)/this.txt $(LIBS_THIS)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,purrc,app.d) $(filter-out purr/app.d,$(call dlangsrc,purr,app.d)) $(DC_CMD_OUT_FLAG)$(BIN)/purrc.o -Ipurr -Illvm/source -J$(TMP) -J$(LIB)

$(TMP)/this.txt:
	$(shell echo $(THIS) > $@)

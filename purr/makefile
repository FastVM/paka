$(call import,dcomp.mak)
LANG=paka

$(BIN)/purr: $(BIN)/purr.o $(LIBS_THIS)
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purr $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR) $(LD_LINK_PURR_LIBS) $^ $(call delsym_many,purr_get_library_plugin,$(LIBS_THIS))

$(BIN)/purr.o: dcomp $(BIN)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,purr,app.d) $(DC_CMD_OUT_FLAG)$(BIN)/purr.o -Ipurr 

# ifeq ($(LANG),paka)
# debug: $(BIN)
# 	$(RUN) dmd -g -Iext -i ext/rt/plugin.d ext/paka/plugin.d ext/serial/plugin.d purr/app.d -od=$(BIN) -of=$(BIN)/paka $(DFLAGS)

# release: $(BIN)
# 	$(RUN) ldc2 -Iext -i ext/rt/plugin.d ext/paka/plugin.d ext/serial/plugin.d purr/app.d -od=$(BIN) -of=$(BIN)/paka $(DFLAGS) -O3 -release
# endif

# ifeq ($(LANG),passerine)
debug: $(BIN)
	$(RUN) dmd -g -Iext -i ext/rt/plugin.d ext/passerine/plugin.d ext/serial/plugin.d purr/app.d -od=$(BIN) -of=$(BIN)/passerine $(DFLAGS)

release: $(BIN)
	$(RUN) ldc2 -Iext -i ext/rt/plugin.d ext/passerine/plugin.d ext/serial/plugin.d purr/app.d -od=$(BIN) -of=$(BIN)/passerine -O3 -release $(DFLAGS)
# endif

LANG=paka

PURR_DIRS=purr/ast purr/bc purr/data purr/fs purr/ir purr/plugin purr/serial purr
PURR_OBJS=$(patsubst %,$(LIB)/%.o,$(subst /,_,$(PURR_DIRS)))

$(BIN)/purr: $(PURR_OBJS) $(LIBS_THIS) $(BIN)
	$(RUN) $(LD_CMD) $(LD_CMD_OUT_FLAG)$(BIN)/purr $(LD_LINK_IN_PURR) $(DFL_FLAG_PURR) $(PURR_OBJS) $(LIBS_THIS) $(EXTRA_LIBS)

$(PURR_OBJS): $(subst _,/,$(patsubst $(LIB)/%.o,%,$@))
	$(RUN) $(DC_CMD) $(OPT_FLAGS) -c $(wildcard $(subst _,/,$(patsubst $(LIB)/%.o,%,$@))/*.d) $(DC_CMD_OUT_FLAG)$@ $(FULL_DFLAGS)

purr: $(BIN)/purr


$(LIB)/libpurr_template.so: $(LIB)/libpurr_template.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_template.o: dcomp $(LIB) $(TMP) 
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/template,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$(LIB)/libpurr_template.o


$(LIB)/libpurr_rt.so: $(LIB)/libpurr_rt.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_rt.o: dummy $(LIB) 
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/rt,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$(LIB)/libpurr_rt.o

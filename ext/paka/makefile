
$(LIB)/libpurr_paka.so: $(LIB)/libpurr_paka.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_paka.o: dummy $(LIB)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,ext/paka,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$@ 

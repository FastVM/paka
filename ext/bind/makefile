
$(LIB)/libpurr_bind.so: $(LIB)/libpurr_bind.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_bind.o: dcomp $(LIB) $(TMP) $(LIB)/libpurr_bind_binder.o
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,ext/bind,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$(LIB)/libpurr_bind.o

$(LIB)/libpurr_bind_binder.o: $(LIB)
	$(eval EXTRA_LIBS+=$(LIB)/libpurr_bind_binder.o)
	@make -s -f ext/bind/chibicc/Makefile binder.o

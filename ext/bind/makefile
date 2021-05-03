
$(LIB)/libpurr_bind.so: $(LIB)/libpurr_bind.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_bind.o: $(LIB)/binder.o $(LIB)/libpurr_bind_dlang.o

$(LIB)/libpurr_bind_dlang.o: dummy 
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,ext/bind,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$(LIB)/libpurr_bind.o

$(LIB)/binder.o: dummy
	$(eval EXTRA_LIBS+=$@)
	$(eval LFLAGS+=-lffi)
	$(MAKE) --no-print-directory -C ext/bind/chibicc -f makefile $@ CC=$(CC_CMD) LIB=$(LIB)

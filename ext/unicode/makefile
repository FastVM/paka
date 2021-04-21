UNICODE=$(TMP)/UnicodeData.txt
BOOL_RECURL=$(call tobool,$(RECURL))

$(LIB)/libpurr_unicode.so: $(LIB)/libpurr_unicode.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)

$(LIB)/libpurr_unicode.o: dcomp $(LIB) $(TMP) $(UNICODE)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) -c $(call dlangsrc,ext/unicode,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$(LIB)/libpurr_unicode.o -J$(TMP)

$(UNICODE): dummy
ifeq ($(wildcard $(UNICODE)),)
	$(RUN) mkdir -p $(dir $(UNICODE))
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
else
ifeq ($(BOOL_RECURL),TRUE)
	$(RUN) mkdir -p $(dir $(UNICODE))
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
else
endif
endif
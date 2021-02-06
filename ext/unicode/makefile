
$(LIB)/libpurr_unicode.so: $(LIB)/libpurr_unicode.o
	$(RUN) $(LD_CMD) -shared $(LD_CMD_OUT_FLAG)$@ $^ $(LD_LINK_IN_LIBS) $(DFL_FLAG_LIBS)  $(LIB)/libpurr_unicode.o

$(LIB)/libpurr_unicode.o: dcomp $(LIB) $(TMP)/UnicodeData.txt
	$(CURL_CMDS_NEEDED)
	$(RUN) $(DC_CMD) $(OPT_FLAGS) $(FULL_DFLAGS) $(REALOCATON_MODE_TO_PIC) -c $(call dlangsrc,ext/unicode,plugin.d) -Ipurr -Iext $(DC_CMD_OUT_FLAG)$(LIB)/libpurr_unicode.o -J$(TMP)

$(TMP)/UnicodeData.txt: $(TMP)
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $(TMP)/UnicodeData.txt
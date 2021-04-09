THIS=paka unicode serial rt
LIBS_NOEXT:=$(patsubst %.so,%,$(patsubst %.o,%,$(LIBS)))
LIBS_SO:=$(patsubst %,$(LIB)/libpurr_%.so,$(LIBS_NOEXT))
LIBS_THIS:=$(patsubst %,$(LIB)/libpurr_%.o,$(THIS))

ALL_LIBS=$(LIBS_NOEXT) $(THIS)

$(call import,ext/paka/makefile)
$(call import,ext/unicode/makefile)
$(call import,ext/serial/makefile)
$(call import,ext/rt/makefile)

MAKEFILE_INCLUDES:=
define MAKEFILE_IMPORT_IMPL_BODY
ifeq ($(findstring $1,$(MAKEFILE_INCLUDES)),)
MAKEFILE_INCLUDES+=$1
include $1
endif
endef

import=$(eval $(MAKEFILE_IMPORT_IMPL_BODY))

$(call import,settings.mak)
$(call import,ext/makefile)
$(call import,purrc/makefile)
$(call import,purr/makefile)

all: $(BIN)/purr $(BIN)/purrc $(LIBS_SO)

clean: dummy
	$(RUN) rm -rf $(BIN) $(LIB) *.so *.o

cleans:
	$(RUN) rm -rf $(BIN) $(LIB) $(TMP) .purr
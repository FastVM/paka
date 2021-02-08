MAKEFILE_INCLUDES:=
define MAKEFILE_IMPORT_IMPL_BODY
ifeq ($(findstring $1,$(MAKEFILE_INCLUDES)),)
MAKEFILE_INCLUDES+=$1
include $1
endif
endef

import=$(eval $(MAKEFILE_IMPORT_IMPL_BODY))
runto=$(shell $2)$(shell echo $2 > $1)
delsym=$(eval DELSYM_TEMPORARY_SHELL:=$(shell mktemp --tmpdir=$(TMP) --suffix= --directory XXXXXXXX))$(call runto,$(DELSYM_TEMPORARY_SHELL)/command.txt,objcopy --strip-symbol=$1 $2 $(DELSYM_TEMPORARY_SHELL)/object.o)$(DELSYM_TEMPORARY_SHELL)/object.o
delsym_many=$(foreach filename,$2,$(call delsym,$1,$(filename)))

$(call import,settings.mak)
$(call import,conv.mak)
$(call import,ext/makefile)
$(call import,purrc/makefile)
$(call import,purr/makefile)

.DEFAULT_GOAL := all
all: $(BIN)/purr $(BIN)/purrc $(BIN)/purrc $(LIBS_SO)

clean: dummy
	$(RUN) rm -rf $(BIN) $(LIB) *.so *.o

cleans: dummy
	$(RUN) rm -rf $(BIN) $(LIB) $(TMP) .purr

cleanuni: dummy
	$(RUN) rm -rf $(BIN) $(LIB) $(TMP) .purr
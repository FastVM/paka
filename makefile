all: purr $(LIBS_SO)

MAKEFILE_INCLUDES:=
define MAKEFILE_IMPORT_IMPL_BODY
ifeq ($(findstring $1,$(MAKEFILE_INCLUDES)),)
MAKEFILE_INCLUDES+=$1
include $1
endif
endef

BIN=bin
LIB=lib
TMP=tmp

BIN:=$(abspath $(BIN))
LIB:=$(abspath $(LIB))
TMP:=$(abspath $(TMP))

import=$(eval $(MAKEFILE_IMPORT_IMPL_BODY))
runto=$(shell $2)$(shell echo $2 > $1)
mkdir=$(shell mkdir -p $1)$1
tmpdir=$(eval $1:=$(shell mktemp --tmpdir=$(call mkdir,$(TMP)) --suffix= --directory XXXXXXXX))
tmpfile=$(call tmpdir,DIR_$1)$(eval DIR_$1:=$1/tmpfile$)
delsym=$(call tmpfile,TMPFILE)$(shell objcopy --strip-symbol=$1 $2 $(TMPFILE))$(TMPFILE)

$(call import,settings.mak)
$(call import,conv.mak)
$(call import,ext/makefile)
$(call import,purr/makefile)

.DEFAULT_GOAL := all

clean: dummy
	$(RUN) rm -rf $(BIN) $(LIB) *.so *.o

deepclean: clean
	$(RUN) rm -rf $(TMP) 

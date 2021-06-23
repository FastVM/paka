OPT=0
BIN=bin
TMP=tmp
DFILES:=$(shell find ext purr -type f -name '*.d')
ifdef GCC
DC=gdc
LOUT=-o
else
DC=ldc2
LOUT=-of=
endif

all: build

opt: $(BIN)
	@$(MAKE) --no-print-directory OPT=s

build: $(BIN) $(BIN)/purr 

$(BIN)/purr: $(DFILES)
	cp drt.d bin/drt.d
	$(DC) $(DFILES) -O$(OPT) -J. $(DFLAGS) $(LFLAGS) $(LOUT)$@

$(TMP):
	@mkdir -p $(TMP)

$(BIN):
	@mkdir -p $(BIN)

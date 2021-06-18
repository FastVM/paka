OPT_D=0
BIN=bin
TMP=tmp
DFILES:=$(shell find ext purr -type f -name '*.d')
ifdef LLVM
DC=ldc2
LOUT=-of=
else
DC=gdc
LOUT=-o
endif

all: build

opt: $(BIN)
	@$(MAKE) --no-print-directory OPT_D=s

build: $(BIN) $(BIN)/purr 

$(BIN)/purr: $(DFILES)
	$(DC) $(DFILES) -O$(OPT_D) -Jtmp $(DFLAGS) $(LFLAGS) $(LOUT)$@

$(TMP):
	@mkdir -p $(TMP)

$(BIN):
	@mkdir -p $(BIN)

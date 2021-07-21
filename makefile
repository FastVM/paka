OPT_C=fast
OPT_D=0
BIN=bin
TMP=tmp
OPT_PGO=$(OPT_C)
DFILES:=$(shell find ext purr -type f -name '*.d')
ifdef LLVM
CC=clang
DC=ldc2
LOUT=-of=
else
CC=gcc
DC=gdc
LOUT=-o
endif

all: build

opt: $(BIN)
	@$(MAKE) --no-print-directory OPT_C=3 OPT_D=s CFLAGS="$(CFLAGS) -fno-stack-protector -fomit-frame-pointer -ffp-contract=off -fno-signed-zeros -fno-trapping-math"

build: $(BIN) compiler 

compiler: minivm
	$(DC) $(DFILES) -O$(OPT_D) $(LOUT)$(BIN)/purr $(BIN)/vm.o -Jtmp $(DFLAGS) $(LFLAGS)

minivm: minivm.c
	$(CC) -c minivm.c -o $(BIN)/vm.o --std=c11 -O$(OPT_C) $(CFLAGS)

$(TMP):
	@mkdir -p $(TMP)

$(BIN):
	@mkdir -p $(BIN)

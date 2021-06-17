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
LFLAGS+=-L/opt/homebrew/lib/gcc/11/libgccjit.so
CFLAGS+=-I/opt/homebrew/include
else
CC=gcc
DC=gdc
LOUT=-o
LFLAGS+=-lgccjit
endif

all: build

opt: $(BIN)
	@$(MAKE) --no-print-directory OPT_C=3 OPT_D=s CFLAGS="$(CFLAGS) -fno-stack-protector -fomit-frame-pointer -ffp-contract=off -fno-signed-zeros -fno-trapping-math"

build: $(BIN) $(BIN)/purr 

$(BIN)/purr: $(BIN)/vm.o
	$(DC) $(DFILES) -O$(OPT_D) $(LOUT)$@ $^ -Jtmp $(DFLAGS) $(LFLAGS)

$(BIN)/vm.o: c/vm.c
	$(CC) -c c/vm.c -o $@ --std=c11 -O$(OPT_C) -fPIC $(CFLAGS)

$(TMP):
	@mkdir -p $(TMP)

$(BIN):
	@mkdir -p $(BIN)

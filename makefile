BIN=bin
TMP=tmp
OPT_PGO=$(OPT_C)
DFILES:=$(shell find ext purr -type f -name '*.d')
CC=clang
DC=ldc2

all: build

opt: $(BIN)
	@$(MAKE) --no-print-directory OPT_C=3 OPT_D=s CFLAGS="$(CFLAGS) -fno-stack-protector -fomit-frame-pointer -ffp-contract=off -fno-signed-zeros -fno-trapping-math"

build: $(BIN) compiler 

compiler: minivm
	$(DC) $(DFILES) -Os -of=$(BIN)/purr $(BIN)/vm.o $(DFLAGS) $(LFLAGS)

minivm: minivm.c
	$(CC) -c minivm.c -o $(BIN)/vm.o --std=gnu11 -Ofast $(CFLAGS)

$(TMP):
	@mkdir -p $(TMP)

$(BIN):
	@mkdir -p $(BIN)

BIN=bin
OPT_PGO=$(OPT_C)
DFILES:=$(shell find ext purr -type f -name '*.d')
CC=clang
DC=ldc2

$(shell mkdir -p $(BIN))

all: $(BIN) $(BIN)/minivm $(BIN)/purr

opt: $(BIN)
	@$(MAKE) --no-print-directory OPT_C=3 OPT_D=s CFLAGS="$(CFLAGS) -fno-stack-protector -fomit-frame-pointer -ffp-contract=off -fno-signed-zeros -fno-trapping-math"

minivm $(BIN)/minivm: main.c minivm.c
	$(CC) --std=gnu11 -Os -o$(BIN)/minivm $^ $(CFLAGS)

purr $(BIN)/purr: $(DFILES) $(BIN)/libminivm.o
	$(DC) -Os -of=$(BIN)/purr $^ $(LFLAGS)

$(BIN)/libminivm.o: minivm.c
	$(CC) -c --std=gnu11 -Ofast -o$@ $^ $(CFLAGS)


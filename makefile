BIN=bin
OPT_PGO=$(OPT_C)
DFILES:=$(shell find ext purr -type f -name '*.d')
CC=gcc
DC=ldc2

$(shell mkdir -p $(BIN))

all: $(BIN) $(BIN)/minivm $(BIN)/purr $(BIN)/asm

minivm $(BIN)/minivm: vm/main.c vm/minivm.c
	$(CC) --std=gnu11 -Ofast -o$(BIN)/minivm $^ $(CFLAGS) -lm -I./

asm $(BIN)/asm: vm/asm.c vm/debug.c vm/minivm.c
	$(CC) --std=gnu11 -Ofast -o$(BIN)/asm $^ $(CFLAGS) -lm -I./

purr $(BIN)/purr: $(DFILES) $(BIN)/libminivm.o
	$(DC) -Os -of=$(BIN)/purr $^ $(LFLAGS)

$(BIN)/libminivm.o: vm/minivm.c
	$(CC) -c -fPIC --std=gnu11 -Ofast -o$@ $^ $(CFLAGS) -I./


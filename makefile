BIN=bin
OPT_PGO=$(OPT_C)
DFILES:=$(shell find ext purr -type f -name '*.d')
CC=gcc
DC=ldc2

$(shell mkdir -p $(BIN))

all: $(BIN) $(BIN)/minivm $(BIN)/purr

minivm $(BIN)/minivm: main.c minivm.c
	$(CC) --std=gnu11 -Ofast -o$(BIN)/minivm $^ $(CFLAGS) -lm

purr $(BIN)/purr: $(DFILES) $(BIN)/libminivm.o
	$(DC) -Os -of=$(BIN)/purr $^ $(LFLAGS)

$(BIN)/libminivm.o: minivm.c
	$(CC) -c -fPIC --std=gnu11 -Ofast -o$@ $^ $(CFLAGS)


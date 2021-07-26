BIN=bin
LIB=lib

CC=clang
DC=ldc2
LD=gcc

PHOBOS=phobos2-ldc-shared

OPT_C=-Ofast
OPT_D=-O

DDIRS:=$(shell find ext/paka purr -type d)
DFILES:=$(shell find ext/paka purr -type f -name '*.d')
OBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))

$(shell mkdir -p $(BIN) $(LIB))

all: $(BIN) $(BIN)/minivm $(BIN)/purr

minivm $(BIN)/minivm: vm/main.c $(LIB)/libminivm.o
	$(CC) $(OPT_C) -o$(BIN)/minivm $^ $(CFLAGS) -lm -I./

asm $(BIN)/asm: vm/asm.c vm/debug.c $(LIB)/libminivm.o
	$(CC) $(OPT_C) -o$(BIN)/asm $^ $(CFLAGS) -lm -I./

purr $(BIN)/purr: $(OBJS) $(LIB)/libminivm.o
	$(LD) $^ -o $(BIN)/purr -lc -lm -l$(PHOBOS) -ldruntime-ldc-shared -lpthread -lrt $(LFLAGS)

$(OBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	$(DC) -c $(OPT_D) -of=$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(LIB)/libminivm.o: vm/minivm.c
	$(CC) -c -fPIC $(OPT_C) -o$@ $^ $(CFLAGS) -I./

.dummy:

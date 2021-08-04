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
CFILES:=minivm/vm/minivm.c minivm/vm/gc.c
OBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))

$(shell mkdir -p $(BIN) $(LIB))

default: purr

purr $(BIN)/purr: $(OBJS) $(LIB)/libminivm.so
	$(LD) $^ -o $(BIN)/purr -lc -lm -l$(PHOBOS) -ldruntime-ldc-shared -lpthread -lrt $(LFLAGS)

$(OBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	$(DC) -c $(OPT_D) -of=$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

minivm $(LIB)/libminivm.so: $(CFILES)
	$(CC) -shared -o $(LIB)/libminivm.so $^ -Iminivm -lm -O$(OPT_C) $(CFLAGS)

.dummy:

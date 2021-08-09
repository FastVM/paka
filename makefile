BIN=bin
LIB=lib

CC=gcc
DC=ldc2

LL=-L-l
LO=-of

OPT_C=-Ofast
OPT_D=-O

NOTOUCH=vm/main.c
NOTNAMEFLAGS=$(patsubst %,-not -path '*%',$(NOTOUCH))

$(info $(NOTNAMEFLAGS))

DDIRS:=$(shell find ext/paka purr -type d)
DFILES:=$(shell find ext/paka purr -type f -name '*.d' $(NOTNAMEFLAGS))
CFILES:=$(shell find minivm/vm -type f -name '*.c' $(NOTNAMEFLAGS))
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS)

$(shell mkdir -p $(BIN) $(LIB))

default: purr

purr $(BIN)/purr: $(OBJS) $(LIB)/libminivm.so
	$(DC) $^ -of=$(BIN)/purr $(LFLAGS)

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	$(DC) -c $(OPT_D) -of=$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS): $(patsubst $(LIB)/%.o,%.c,$@)
	$(shell mkdir -p $(dir $@))
	$(CC) -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(CFLAGS)

.dummy:

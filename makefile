BIN=bin
LIB=lib

CC=clang
DC=ldc2

ifeq ($(DC),gdc)
DO=-o
else
DO=-of=
endif

OPT_C=-Ofast
OPT_D=

NOTOUCH=vm/main.c vm/gc1.c
NOTNAMEFLAGS=$(patsubst %,-not -path '*%',$(NOTOUCH))

DFILES:=$(shell find ext/paka purr -type f -name '*.d' $(NOTNAMEFLAGS))
CFILES:=$(shell find minivm/vm -type f -name '*.c' $(NOTNAMEFLAGS))
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS) $(LIB)/libmimalloc.a

$(shell mkdir -p $(BIN) $(LIB))

default: purr

purr $(BIN)/purr: $(OBJS)
	$(DC) $^ $(DO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(DLFLAGS)

$(LIB)/libmimalloc.a:
	$(MAKE) --no-print-directory -C minivm -f mimalloc.mak > /dev/null
	cp minivm/lib/libmimalloc.a $@

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	$(DC) -c $(OPT_D) $(DO)$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS): $(patsubst $(LIB)/%.o,%.c,$@)
	$(shell mkdir -p $(dir $@))
	$(CC) -fPIE -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(CFLAGS)
	
.dummy:

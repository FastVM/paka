BIN=$(shell pwd)/bin
LIB=$(shell pwd)/lib

CC=gcc
DC=ldc2

OPT_C=-Ofast -ffast-math
OPT_C_GC=-O3 -ffast-math
OPT_D=-Os

P=-p

GC_OBJ=$(LIB)/minivm/vm/gc.o

MICC=$(CC)

ifeq ($(DC),gdc)
DO=-o
DL=
else
DO=-of=
DL=-L
endif


DFILES:=$(shell find ext/paka purr -type f -name '*.d')
CFILES:=$(shell find minivm/vm -type f -name '*.c')
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS) $(LIB)/libmimalloc.a

default:
	$(MAKE) $(BIN) $(LIB) P=$(P)
	$(MAKE) purr $(BIN)/minivm P=$(P) BIN="$(BIN)" LIB="$(LIB)"

purr $(BIN)/purr: $(OBJS)
	@mkdir $(P) $(BIN)
	$(DC) $^ $(DO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(DLFLAGS)

minivm $(BIN)/minivm: $(COBJS) $(LIB)/minivm/main/main.o $(LIB)/libmimalloc.a
	$(CC) $^ -o $(BIN)/minivm -I. -lm -lpthread $(LFLAGS) $(CLFLAGS)

$(LIB)/libmimalloc.a: minivm/mimalloc
	$(MAKE) --no-print-directory -C minivm -f mimalloc.mak CC=$(MICC) LIB=$(LIB)

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(DC) -c $(OPT_D) $(DO)$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS) $(LIB)/minivm/main/main.o: $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(CC) -fPIC -c $(if $(findstring $@,$(GC_OBJ)),$(OPT_C_GC),$(OPT_C)) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(CFLAGS) 

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -r $(BIN) $(LIB)

BIN=bin
LIB=lib

CC=gcc
DC=ldc2

OPT_C=-Ofast -ffast-math
OPT_C_GC=-O3 -ffast-math
OPT_D=-Os

P=-p

GC_OBJ=$(LIB)/minivm/vm/gc.o

ifeq ($(MACOS),1)
LIBFFI=/opt/homebrew/Cellar/libffi/3.3_3/lib/libffi.a
INCFFI=-I/opt/homebrew/Cellar/libffi/3.3_3/include
else
LIBFFI=-lffi
endif

MICC=gcc

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
OBJS=$(DOBJS) $(COBJS)

default:
	$(MAKE) $(BIN) $(LIB) P=$(P)
	$(MAKE) purr minivm P=$(P)

purr $(BIN)/purr: $(OBJS)
	@mkdir $(P) $(BIN)
	$(DC) $^ $(DO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(DL)$(LIBFFI) $(DLFLAGS)

minivm: $(CFILES) minivm/main/main.c
	$(MAKE) --no-print-directory -C minivm BIN=bin CC="$(CC)" OPT="$(OPT_C)"
	cp minivm/bin/minivm $(BIN)/minivm

# $(LIB)/libmimalloc.a: minivm/mimalloc
# 	$(MAKE) --no-print-directory -C minivm -f mimalloc.mak CC=$(MICC)
# 	cp minivm/lib/libmimalloc.a $@

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(DC) -c $(OPT_D) $(DO)$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS): $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(CC) -fPIC -c $(if $(findstring $@,$(GC_OBJ)),$(OPT_C_GC),$(OPT_C)) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(INCFFI) $(CFLAGS) 

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -r $(BIN) $(LIB)

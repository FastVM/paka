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


DFILES:=$(shell find ext/paka ext/scheme purr -type f -name '*.d')
CFILES:=$(shell find minivm/vm -type f -name '*.c')
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS) $(LIB)/libmimalloc.a

default:
	$(MAKE) $(BIN) $(LIB) P=$(P)
	$(MAKE) purr

purr $(BIN)/purr: $(OBJS)
	@mkdir $(P) $(BIN)
	$(DC) $^ $(DO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(DL)$(LIBFFI) $(DLFLAGS)

$(LIB)/libmimalloc.a: minivm/mimalloc
	$(MAKE) --no-print-directory -C minivm -f mimalloc.mak CC=$(MICC)
	cp minivm/lib/libmimalloc.a $@

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

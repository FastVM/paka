BIN=bin
LIB=lib

CC=gcc
DC=ldc2

OPT_C=-Ofast
OPT_D=-Os

P=-p

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


# DFILES:=$(shell find ext/paka purr -type f -name '*.d' $(NOTNAMEFLAGS))
DFILES=ext/paka/plugin.d ext/paka/parse/tokens.d ext/paka/parse/util.d ext/paka/parse/parse.d ext/paka/parse/op.d purr/ast/walk.d purr/ast/ast.d purr/plugin/plugin.d purr/plugin/plugins.d purr/err.d purr/parse.d purr/srcloc.d purr/inter.d purr/vm/package.d purr/vm/bytecode.d purr/vm/ffi.d purr/app.d
# CFILES:=$(shell find minivm/vm -type f -name '*.c' $(NOTNAMEFLAGS))
CFILES=minivm/vm/ffiop.c minivm/vm/minivm.c minivm/vm/gc.c
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS) $(LIB)/libmimalloc.a

# $(shell mkdir $(BIN) $(LIB))

default:
	$(MAKE) $(BIN) $(LIB) P=$(P)
	$(MAKE) purr

purr $(BIN)/purr: $(OBJS)
	$(DC) $^ $(DO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(DL)$(LIBFFI) $(DLFLAGS)

$(LIB)/libmimalloc.a: minivm/mimalloc
	$(MAKE) --no-print-directory -C minivm -f mimalloc.mak CC=$(MICC)
	cp minivm/lib/libmimalloc.a $@

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	$(DC) -c $(OPT_D) $(DO)$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS): $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(LIB)/minivm/vm
	$(CC) -fPIC -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(INCFFI) $(CFLAGS) 
	
$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -r $(BIN) $(LIB)

BIN:=$(shell pwd)/bin
LIB:=$(shell pwd)/lib

CC=clang
DC=gdc
LD=$(DC)

OPT_C=-Ofast
OPT_C_GC=-Ofast
OPT_D=-Os

P=-p
FPIC=-fPIC

MICC=$(CC)

ifeq ($(LD),$(DC))
XLFLAGS=$(DLFLAGS)
else
ifeq ($(DC),gdc)
XLFLAGS=$(DL)-lgphobos $(DL)-lgdruntime $(DL)-lm $(DL)-lpthread
else
XLFLAGS=$(DL)-lphobos2-ldc-shared $(DL)-ldruntime-ldc-shared $(DL)-lm $(DL)-lpthread
endif
endif

ifeq ($(DC),gdc)
DO=-o
else
DO=-of
endif

ifeq ($(LD),dmd)
DL=-L
LDO=-of
else
ifeq ($(LD),ldc2)
DL=-L
LDO=-of
else
DL=
LDO=-o
endif
endif


DFILES:=$(shell find ext purr -type f -name '*.d')
CFILES:=$(shell find minivm/vm -type f -name '*.c' -not -name wasm.c)
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS) $(LIB)/libmimalloc.a
GC_OBJ=$(LIB)/minivm/vm/gc.o

default:
	$(MAKE) $(BIN) $(LIB) P=$(P)
	$(MAKE) purr $(BIN)/minivm P=$(P) BIN="$(BIN)" LIB="$(LIB)"

purr $(BIN)/purr: $(OBJS)
	@mkdir $(P) $(BIN)
	$(LD) $^ $(LDO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(XLFLAGS)

minivm $(BIN)/minivm: $(COBJS) $(LIB)/minivm/main/main.o $(LIB)/libmimalloc.a
	$(LD) $^ -o $(BIN)/minivm -I. -lm -lpthread $(LFLAGS) $(CLFLAGS)

$(LIB)/libmimalloc.a: minivm/mimalloc
	$(MAKE) --no-print-directory -C minivm -f mimalloc.mak CC=$(MICC) LIB=$(LIB) CFLAGS=""

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(DC) -c $(OPT_D) $(DO)$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS) $(LIB)/minivm/main/main.o: $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(if $(findstring $@,$(GC_OBJ)),$(CC_GC),$(CC)) $(FPIC) -c $(if $(findstring $@,$(GC_OBJ)),$(OPT_C_GC),$(OPT_C)) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(CFLAGS) 

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -r $(BIN) $(LIB)

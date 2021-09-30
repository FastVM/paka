BIN:=$(shell pwd)/bin
LIB:=$(shell pwd)/lib

CC=clang
DC=gdc
LD=$(DC)

OPT_C=-Ofast
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
C1FILES=minivm/vm/vm.c minivm/vm/gc.c 
C2FILES=minivm/vm/backend/js.c minivm/vm/backend/lua.c
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
C1OBJS=$(patsubst %.c,$(LIB)/%.o,$(C1FILES))
C2OBJS=$(patsubst %.c,$(LIB)/%.o,$(C2FILES))
COBJS=$(C1OBJS) $(C2OBJS)
OBJS=$(DOBJS) $(COBJS) $(LIB)/libmimalloc.a

default:
	$(MAKE) $(BIN) $(LIB) P=$(P)
	$(MAKE) $(BIN)/purr $(BIN)/minivm P=$(P) BIN="$(BIN)" LIB="$(LIB)"

purr $(BIN)/purr: $(OBJS)
	@mkdir $(P) $(BIN)
	$(LD) $^ $(LDO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(XLFLAGS)

minivm $(BIN)/minivm: $(C1OBJS) $(LIB)/minivm/main/main.o $(LIB)/libmimalloc.a
	@mkdir $(P) $(BIN)
	$(LD) $^ -o $(BIN)/minivm -I. -lm -lpthread $(LFLAGS) $(XLFLAGS)

vm $(BIN)/vm: $(C1FILES) minivm/main/main.c $(LIB)/libmimalloc.a
	$(CC) $^ -o $(BIN)/vm -Iminivm -lm -lpthread $(FPIC) $(OPT_C) $(LFLAGS) $(CLFAGS)

$(LIB)/libmimalloc.a: minivm/mimalloc
	$(MAKE) --no-print-directory -C minivm -f mimalloc.mak CC=$(MICC) LIB=$(LIB) CFLAGS=""

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(DC) -c $(OPT_D) $(DO)$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS) $(LIB)/minivm/main/main.o: $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(CC) $(FPIC) -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(CFLAGS) 

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -r $(BIN) $(LIB)

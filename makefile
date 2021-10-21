BIN:=$(shell pwd)/bin
LIB:=$(shell pwd)/lib

CC=clang
DC=gdc
LD=$(DC)

OPT_C=-Ofast
OPT_D=-Os

P=-p
FPIC=-fPIC

ifeq ($(LD),$(DC))
XLFLAGS=$(DLFLAGS)
else
ifeq ($(DC),gdc)
XLFLAGS=$(DL)-lgphobos $(DL)-lgdruntime $(DL)-lm $(DL)-lpthread
else
XLFLAGS=$(DL)-lphobos2-ldc $(DL)-ldruntime-ldc $(DL)-lm $(DL)-lz $(DL)-ldl $(DL)-lpthread
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

MIMALLOC=$(DL)-lmimalloc -DVM_USE_MIMALLOC

DFILES:=$(shell find ext purr minivm/optimize -type f -name '*.d')
CFILES=minivm/vm/vm.c minivm/vm/io.c minivm/vm/gc.c minivm/vm/xobj.c
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS)

default: $(BIN)/purr $(BIN)/minivm

purr $(BIN)/purr: $(OBJS)
	@mkdir $(P) $(BIN)
	$(LD) $^ $(LDO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(MIMALLOC) $(XLFLAGS)

minivm $(BIN)/minivm: $(COBJS) $(LIB)/minivm/main/main.o $(LIB)/minivm/vm/sys.o
	@mkdir $(P) $(BIN)
	$(LD) $^ -o $(BIN)/minivm -I. -lm $(LFLAGS) $(MIMALLOC) $(XLFLAGS)

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(dir $@) $(LIB)
	$(DC) -Jimport -c $(OPT_D) $(DO)$@ -Iminivm $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS) $(LIB)/minivm/main/main.o $(LIB)/minivm/vm/sys.o: $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(dir $@) $(LIB)
	$(CC) $(FPIC) -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(CFLAGS) 

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -r $(BIN) $(LIB)

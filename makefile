PWD:=$(shell pwd)
BIN:=$(PWD)/bin
LIB:=$(PWD)/lib

MICC=$(CC)
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
XLFLAGS=$(DL)-L/usr/local/lib $(DL)-lphobos2-ldc $(DL)-ldruntime-ldc $(DL)-lm $(DL)-lz $(DL)-ldl $(DL)-lpthread
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

MIMALLOC=$(DL)$(PWD)/minivm/lib/libmimalloc.a

DFILES:=$(shell find ext purr -type f -name '*.d')
CFILES=minivm/vm/vm.c minivm/vm/io.c minivm/vm/gc.c minivm/vm/obj/map.c
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS)

default: $(BIN)/purr $(BIN)/minivm

purr $(BIN)/purr: $(OBJS) $(MIMALLOC)
	@mkdir $(P) $(BIN)
	$(LD) $(OBJS) $(LDO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(XLFLAGS)

minivm $(BIN)/minivm: $(COBJS) $(LIB)/minivm/main/main.o $(MIMALLOC)
	@mkdir $(P) $(BIN)
	$(LD) $(COBJS) $(LIB)/minivm/main/main.o $(LDO)$(BIN)/minivm $(LFLAGS) $(MIMALLOC) $(XLFLAGS)

$(MIMALLOC): .dummy
	make -C minivm -f mimalloc.mak --no-print-directory CC=$(MICC)

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(dir $@) $(LIB)
	$(DC) -Jimport -c $(OPT_D) $(DO)$@ -Iminivm $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS) $(LIB)/minivm/main/main.o: $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(dir $@) $(LIB)
	$(CC) $(FPIC) -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(CFLAGS)

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	$(MAKE) -C minivm -f makefile clean
	$(MAKE) -C minivm -f mimalloc.mak clean
	: rm -r $(BIN) $(LIB)

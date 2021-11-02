PWD:=$(shell pwd)
BIN:=$(PWD)/bin
LIB:=$(PWD)/lib

MICC?=$(CC)
DC?=gdc
LD=$(DC)

OPT_C=-Ofast
OPT_D=

P=-p
FPIC=-fPIC

# LFLAGS+=$(FLAGS)
# CFLAGS+=$(FLAGS)
# DFLAGS+=$(FLAGS)

ifeq ($(LD),$(DC))
XLFLAGS=$(DLFLAGS)
else
ifeq ($(DC),gdc)
XLFLAGS=$(DL)-lgphobos $(DL)-lgdruntime $(DL)-lm $(DL)-lpthread
else
ifeq ($(DC),ldc2)
XLFLAGS=$(DL)-L/usr/local/lib $(DL)-lphobos2-ldc $(DL)-ldruntime-ldc $(DL)-lm $(DL)-lz $(DL)-ldl $(DL)-lpthread
else
XLFLAGS=$(DL)-L/usr/local/lib $(DL)-lphobos2 $(DL)-lm $(DL)-lz $(DL)-ldl $(DL)-lpthread
endif
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

ifeq ($(MI),1)
MIMALLOC=$(DL)$(PWD)/minivm/lib/mimalloc/libmimalloc.a
L_MIMALLOC=$(DL)$(PWD)/minivm/lib/mimalloc/libmimalloc.a
C_MIMALLOC=-DVM_USE_MIMALLOC
endif

DFILES:=$(shell find ext purr -type f -name '*.d')
CFILES=$(shell find ext minivm/vm -type f -name '*.c')
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS)

default: $(BIN)/purr $(BIN)/minivm

purr $(BIN)/purr: $(OBJS) $(MIMALLOC)
	@mkdir $(P) $(BIN)
	$(LD) $(OBJS) $(LDO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(MIMALLOC) $(XLFLAGS)

minivm $(BIN)/minivm: $(COBJS) $(LIB)/minivm/main/main.o $(MIMALLOC)
	@mkdir $(P) $(BIN)
	$(LD) $(COBJS) $(LIB)/minivm/main/main.o $(LDO)$(BIN)/minivm $(LFLAGS) $(MIMALLOC) $(L_MIMALLOC) $(XLFLAGS) $(AFLAGS)

$(MIMALLOC): .dummy
	$(MAKE) -C minivm -f deps.mak --no-print-directory CC="$(MICC)" CFLAGS="" LFLAGS=""

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(dir $@) $(LIB)
	$(DC) -Jimport -c $(OPT_D) $(DO)$@ -Iminivm $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS) $(AFLAGS)

$(COBJS) $(LIB)/minivm/main/main.o: $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(dir $@) $(LIB)
	$(CC) $(FPIC) -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(C_MIMALLOC) $(CFLAGS) $(AFLAGS)

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	$(MAKE) -C minivm -f makefile clean
	$(MAKE) -C minivm -f mimalloc.mak clean
	: rm -r $(BIN) $(LIB)

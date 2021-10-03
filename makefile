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

THREADS=-DVM_GC_THREADS

DFILES:=$(shell find ext purr -type f -name '*.d')
CFILES=minivm/vm/vm.c minivm/vm/gc.c 
DOBJS=$(patsubst %.d,$(LIB)/%.o,$(DFILES))
COBJS=$(patsubst %.c,$(LIB)/%.o,$(CFILES))
OBJS=$(DOBJS) $(COBJS)

default: $(BIN)/purr $(BIN)/minivm

purr $(BIN)/purr: $(OBJS)
	@mkdir $(P) $(BIN)
	$(LD) $^ $(LDO)$(BIN)/purr $(patsubst %,$(DL)%,$(LFLAGS)) $(XLFLAGS)

minivm $(BIN)/minivm: $(COBJS) $(LIB)/minivm/main/main.o 
	@mkdir $(P) $(BIN)
	$(LD) $^ -o $(BIN)/minivm -I. -lm -lpthread $(LFLAGS) $(XLFLAGS)

$(DOBJS): $(patsubst $(LIB)/%.o,%.d,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(DC) -c $(OPT_D) $(DO)$@ $(patsubst $(LIB)/%.o,%.d,$@) $(DFLAGS)

$(COBJS) $(LIB)/minivm/main/main.o: $(patsubst $(LIB)/%.o,%.c,$@)
	@mkdir $(P) $(basename $@) $(LIB)
	$(CC) $(FPIC) -c $(OPT_C) -o $@ $(patsubst $(LIB)/%.o,%.c,$@) -I./minivm $(THREADS) $(CFLAGS) 

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -r $(BIN) $(LIB)

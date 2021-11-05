BIN:=bin
LIB:=lib

OPT_C=-Ofast
OPT_D=

MICC=cc

P=-p
FPIC=-fPIC

.if $(DC) == gdc
DO=-o
.else
DO=-of
.endif

# MIMALLOC=$(DL)$(PWD)/minivm/lib/mimalloc/libmimalloc.a
# L_MIMALLOC=$(DL)$(PWD)/minivm/lib/mimalloc/libmimalloc.a
# C_MIMALLOC=-DVM_USE_MIMALLOC

DFILES!=find ext purr -type f -name '*.d'
CFILES!=find ext minivm/vm -type f -name '*.c'
DOBJS=$(DFILES:%.d=%.o)
COBJS=$(CFILES:%.c=%.o)
OBJS=$(DOBJS) $(COBJS)

BINS=$(BIN)/purr $(BIN)/minivm

default: $(BIN)/purr $(BIN)/minivm

purr $(BIN)/purr: $(OBJS) $(MIMALLOC)
	@mkdir $(P) $(BIN)
	$(DC) $(OBJS) $(LDO)$(BIN)/purr $(LFLAGS) $(MIMALLOC) 

minivm $(BIN)/minivm: $(COBJS) minivm/main/main.o $(MIMALLOC)
	@mkdir $(P) $(BIN)
	$(CC) $(COBJS) minivm/main/main.o -o$(BIN)/minivm -lm $(LFLAGS) $(MIMALLOC) $(L_MIMALLOC)

$(MIMALLOC): .dummy
	$(MAKE) -C minivm -f deps.mak default CC="$(MICC)" CFLAGS="" LFLAGS=""

$(DOBJS): $(patsubst %.o,%.d,$@)
	$(DC) -Jimport -c $(OPT_D) $(DO)$@ -Iminivm $(@:%.o=%.d) $(DFLAGS)

$(COBJS) minivm/main/main.o: $(@:%.o=%.c)
	$(CC) $(FPIC) -c $(OPT_C) -o $@ $(@:%.o=%.c) -I./minivm $(C_MIMALLOC) $(CFLAGS)

$(BIN) $(LIB):
	mkdir $(P) $@

.dummy:

clean:
	rm -rf $(OBJS) $(BINS)

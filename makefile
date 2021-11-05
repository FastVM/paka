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

.if defined(MI)
.if $(MI) == 1
MIMALLOC=$(DL)$(PWD)/minivm/lib/mimalloc/libmimalloc.a
L_MIMALLOC=$(DL)$(PWD)/minivm/lib/mimalloc/libmimalloc.a
C_MIMALLOC=-DVM_USE_MIMALLOC
.endif
.endif

.if defined(RE)
.if $(RE) == 1
REBUILD=.dummy
.endif
.endif

DFILES!=find ext purr -type f -name '*.d'
CFILES!=find ext minivm/vm -type f -name '*.c'
DOBJS=$(DFILES:%.d=%.o)
COBJS=$(CFILES:%.c=%.o)
OBJS=$(DOBJS) $(COBJS)

BINS=$(BIN)/purr $(BIN)/minivm

PWD != pwd
.for FILE in $(CFILES)
XTMP != $(CC) -M -MV -o $(FILE:%.c=%.dep) $(FILE)
.endfor

-include $(CFILES:%.c=%.dep)

default: $(BINS)

purr $(BIN)/purr: $(OBJS) $(MIMALLOC) $(REBUILD)
	@mkdir $(P) $(BIN)
	$(DC) $(OBJS) $(DO)$(BIN)/purr $(LFLAGS) $(MIMALLOC)

minivm $(BIN)/minivm: $(COBJS) minivm/main/main.o $(MIMALLOC) $(REBUILD)
	@mkdir $(P) $(BIN)
	$(CC) $(COBJS) minivm/main/main.o -o$(BIN)/minivm -lm $(LFLAGS) $(MIMALLOC) $(L_MIMALLOC)

$(MIMALLOC): .dummy
	$(MAKE) -C minivm -f deps.mak default CC="$(MICC)" CFLAGS="" LFLAGS=""

$(DOBJS): $(@:%.o=%.d) $(REBUILD)
	$(DC) -Jimport -c $(OPT_D) $(DO)$@ -Iminivm $(@:%.o=%.d) $(DFLAGS)

$(COBJS) minivm/main/main.o: $(@:%.o=%.c) $(basename $@) $(REBUILD)
	$(CC) -M -o $(@:%.o=%.dep) $(@:%.o=%.c)
	$(CC) $(FPIC) -c $(OPT_C) -o $@ $(@:%.o=%.c) -I./minivm $(C_MIMALLOC) $(CFLAGS)

info:
	@echo $(XCUR)

.dummy:

clean:
	rm -rf $(OBJS) $(BINS) $(CFILES:%.c=$(PWD)/%.dep)

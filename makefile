OPT=3
OPT_C=$(OPT)
OPT_D=$(OPT)
BIN=bin
TMP=tmp
UNICODE=$(TMP)/UnicodeData.txt
1LFLAGS=$(BIN)/vm.o

all: build
pgo: pgo-build

build: $(BIN) $(UNICODE) minivm
	ldc2 -i purr/app.d ext/*/plugin.d -O$(OPT_D) -of=$(BIN)/purr -Jtmp $(1LFLAGS) $(DFLAGS) $(LFLAGS)

minivm: $(BIN)
	clang -c minivm.c -o $(BIN)/vm.o --std=c99 -O$(OPT_C) $(CFLAGS)

pgo-gen: $(BIN)
	$(MAKE) OPT=3 DFLAGS+="-release --stack-protector-guard=none --frame-pointer=none --fp-contract=off -flto=full -fprofile-instr-generate=profile.raw"
	./bin/purr --file=bench/paka/{fib40,tree,while}.paka
	ldc-profdata merge -output=profile.data profile.raw
	
pgo-build: pgo-gen
	$(MAKE) OPT=3 DFLAGS+="-release --stack-protector-guard=none --frame-pointer=none --fp-contract=off -flto=full -fprofile-instr-use=profile.data"

$(TMP):
	mkdir -p $(TMP)

$(BIN):
	mkdir -p $(BIN)
	
$(UNICODE): $(TMP)
ifeq ($(wildcard $(TMP)/UnicodeData.txt),)
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
endif
OPT=0
BIN=bin
TMP=tmp
UNICODE=$(TMP)/UnicodeData.txt

all: build
pgo: pgo-build

build: $(BIN)
	ldc2 -i purr/app.d ext/*/plugin.d -O$(OPT) -of=$(BIN)/purr -Jtmp $(DFLAGS) 

pgo-gen: $(BIN)
	$(MAKE) -f macos.mak OPT=3 DFLAGS+="-release --stack-protector-guard=none --frame-pointer=none --fp-contract=off -flto=full -fprofile-instr-generate=profile.raw"
	./bin/purr --file=bench/paka/{fib40,table,tree,while}.paka
	ldc-profdata merge -output=profile.data profile.raw
	
pgo-build: pgo-gen
	$(MAKE) -f macos.mak OPT=3 DFLAGS+="-release --stack-protector-guard=none --frame-pointer=none --fp-contract=off -flto=full -fprofile-instr-use=profile.data"

$(TMP):
	mkdir -p $(TMP)

$(BIN):
	mkdir -p $(BIN)
	
$(UNICODE): dummy
ifeq ($(wildcard $(UNICODE)),)
	$(RUN) mkdir -p $(dir $(UNICODE))
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
else
ifeq ($(BOOL_RECURL),TRUE)
	$(RUN) mkdir -p $(dir $(UNICODE))
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
else
endif
endif
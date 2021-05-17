OPT=0
BIN=bin
TMP=tmp
UNICODE=$(TMP)/UnicodeData.txt

all: build
pgo: pgo-build

build: $(BIN) $(UNICODE)
	ldc2 -i purr/app.d ext/*/plugin.d -O$(OPT) -of=$(BIN)/purr -Jtmp $(DFLAGS)

pgo-gen: $(BIN)
	$(MAKE) OPT=3 DFLAGS+="-release --stack-protector-guard=none --frame-pointer=none --fp-contract=off -flto=full -fprofile-instr-generate=profile.raw"
	./bin/purr --file=bench/paka/{fizzbuzz,fib40,table,tree,while}.paka
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
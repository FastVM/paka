OPT=3
OPT_C=$(OPT)
OPT_D=$(OPT)
BIN=bin
TMP=tmp
UNICODE=$(TMP)/UnicodeData.txt
1LFLAGS=$(BIN)/vm.o

all: build
pgo: pgo-build

opt: $(BIN)
	$(MAKE) OPT_C=fast CFLAGS+="-fno-stack-protector -fomit-frame-pointer -ffp-contract=off -flto"

build: $(BIN) $(UNICODE) minivm
	ldc2 -i purr/app.d ext/*/plugin.d -O$(OPT_D) -of=$(BIN)/purr -Jtmp $(1LFLAGS) $(DFLAGS) $(LFLAGS)

minivm: $(BIN)
	$(CC) -c minivm.c -o $(BIN)/vm.o --std=c11 -O$(OPT_C) $(CFLAGS)


pgo-gen: $(TMP)
	$(MAKE) OPT_C=3 OPT_D=0 CFLAGS+="-fprofile-generate=$(TMP)/profile" LFLAGS+=-L-lgcov
	./bin/purr --file=bench/paka/fib40.paka
	
pgo-build: pgo-gen $(TMP)
	$(MAKE) OPT_C=fast CFLAGS+="-fno-stack-protector -fomit-frame-pointer -ffp-contract=off -flto -fprofile-use=$(TMP)/profile"

$(TMP):
	mkdir -p $(TMP)

$(BIN):
	mkdir -p $(BIN)
	
$(UNICODE): $(TMP)
ifeq ($(wildcard $(TMP)/UnicodeData.txt),)
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
endif
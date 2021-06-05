OPT=3
OPT_C=$(OPT)
OPT_D=$(OPT)
BIN=bin
TMP=tmp
UNICODE=$(TMP)/UnicodeData.txt
1LFLAGS=$(BIN)/vm.o

all: build
pgo: 
	$(MAKE) pgo-gen
	$(MAKE) pgo-build

opt: $(BIN)
	$(MAKE) OPT=3 CFLAGS+="-fno-stack-protector -fomit-frame-pointer -ffp-contract=off -flto"

build: $(BIN) $(UNICODE) minivm
	ldc2 -i purr/app.d ext/*/plugin.d -O$(OPT_D) -of=$(BIN)/purr -Jtmp $(1LFLAGS) $(DFLAGS) $(LFLAGS)

minivm: $(BIN)
	$(CC) -c minivm.c -o $(BIN)/vm.o --std=c11 -O$(OPT_C) $(CFLAGS)

pgo-gen: $(TMP)
ifdef LLVM
	$(MAKE) OPT_C=3 OPT_D=0 CFLAGS+="-fprofile-generate=$(TMP)/profile_llvm" DFLAGS+="-fprofile-generate=$(TMP)/dprofile"
	./bin/purr --file=bench/paka/fib40.paka
	llvm-profdata merge $(TMP)/profile_llvm --output=$(TMP)/cprofile_llvm
else
	$(MAKE) OPT_C=3 OPT_D=0 LFLAGS+=-L-lgcov CFLAGS+="-fprofile-generate=$(TMP)/cprofile_gcc" DFLAGS+="-fprofile-generate=$(TMP)/dprofile"
	./bin/purr --file=bench/paka/fib40.paka
endif
	
pgo-build: $(TMP)
ifdef LLVM
	$(MAKE) OPT_C=fast CFLAGS+="-fno-stack-protector -fomit-frame-pointer -ffp-contract=off -flto -fprofile-use=$(TMP)/cprofile_llvm -fno-signed-zeros -fno-trapping-math -mllvm -polly"
else
	$(MAKE) OPT_C=fast CFLAGS+="-fno-stack-protector -fomit-frame-pointer -ffp-contract=off -flto -fprofile-use=$(TMP)/cprofile_gcc -fno-signed-zeros -fno-trapping-math"
endif

$(TMP):
	mkdir -p $(TMP)

$(BIN):
	mkdir -p $(BIN)
	
$(UNICODE): $(TMP)
ifeq ($(wildcard $(TMP)/UnicodeData.txt),)
	$(RUN) curl https://www.unicode.org/Public/UCD/latest/ucd/UnicodeData.txt > $@
endif
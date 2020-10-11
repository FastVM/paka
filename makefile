
COMPILER=ldmd2
LINKER=ld
LINK_FLAGS=gmp mpfr
OUTPUT=dextc
DLANG_OPTIMIZE=-O3 -ffast-math -g --boundscheck=off -release
DLANG_FLAGS=$(DLANG_OPTIMIZE) -Isource
DLANG_SOURCE=$(shell find source | grep \.d$)
OBJS=$(DLANG_SOURCE:source/%.d=out/%.o)
DOCS=$(DLANG_SOURCE:source/%.d=docs/%.html)
# LTO_BINARY=/usr/lib/llvm-10/lib/LLVMgold.so
# LTO=-flto=full -flto-binary=$(LTO_BINARY)

docs: $(DOCS)
	$(COMPILER) $(OBJS) $(patsubst %,-L-l%,$(LINK_FLAGS)) -ofdext # $(LTO)

dext: $(OBJS) 
	$(COMPILER) $(OBJS) $(patsubst %,-L-l%,$(LINK_FLAGS)) -ofdext # $(LTO)

$(DOCS): $(patsubst docs/%.html,source/%.d,$@) makefile
	$(COMPILER) $(patsubst docs/%.html,source/%.d,$@) -c -Df$@ -of$(patsubst docs/%.html,out/%.o,$@) $(DLANG_FLAGS)

$(OBJS): $(patsubst out/%.o,source/%.d,$@) makefile
	$(COMPILER) $(patsubst out/%.o,source/%.d,$@) -c -of$@ $(DLANG_FLAGS)

.PHONY: clean
clean:
	rm -rf dext out docs

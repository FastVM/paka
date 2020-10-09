COMPILER=ldc2
LINKER=ld
LINK_FLAGS=gmp mpfr
OUTPUT=dextc
DLANG_OPTIMIZE=-O3 -ffast-math -g
DLANG_FLAGS=$(DLANG_OPTIMIZE) -Isource
DLANG_SOURCE=$(shell find source | grep \.d$)
OBJS=$(DLANG_SOURCE:source/%.d=out/%.o)
# TIMER=time -f$@:%es
# LTO_BINARY=/usr/lib/llvm-10/lib/LLVMgold.so
# LTO=-flto=full -flto-binary=$(LTO_BINARY)

dext: $(OBJS) 
	$(COMPILER) $(OBJS) $(patsubst %,-L-l%,$(LINK_FLAGS)) -of$@ # $(LTO)

$(OBJS): $(patsubst out/%.o,source/%.d,$@) makefile
# $(OBJS): $(DLANG_SOURCE)
	$(TIMER) $(COMPILER) $(patsubst out/%.o,source/%.d,$@) -c -of$@ $(DLANG_FLAGS)

.PHONY: clean
clean:
	rm -rf dext out

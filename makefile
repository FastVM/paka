COMPILER=ldc2
LINKER=ld
LINK_FLAGS=gmp mpfr
OUTPUT=dextc
DLANG_OPTIMIZE=-O2 -ffast-math -g
DLANG_FLAGS=$(DLANG_OPTIMIZE) -Isource
DLANG_SOURCE=$(shell find source | grep \.d$)
OBJS=$(DLANG_SOURCE:source/%.d=out/%.o)

dext: $(OBJS) 
	$(COMPILER) $(OBJS) $(patsubst %,-L-l%,$(LINK_FLAGS)) -of$@

$(OBJS): $(DLANG_SOURCE)
	$(COMPILER) $(patsubst out/%.o,source/%.d,$@) -c -of$@  $(DLANG_FLAGS)

.PHONY: clean
clean:
	rm -rf dext out

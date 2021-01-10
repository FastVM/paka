
COMPILER=ldmd2
LINKER=ld
OUTPUT=dextc
DLANG_OPTIMIZE=
DLANG_FLAGS=$(DLANG_OPTIMIZE) -Isource
QUEST_SOURCE=$(shell find source/lang/quest)
DLANG_SOURCE=$(shell find source | grep -E \\.d$)
OBJS=$(DLANG_SOURCE:source/%.d=out/%.o)
DOCS=$(DLANG_SOURCE:source/%.d=docs/%.html)

echo:
	echo $(DLANG_SOURCE)

docs: $(DOCS)
	$(COMPILER) $(OBJS) -of=dext $(LTO)

dext: $(OBJS) 
	$(COMPILER) $(OBJS) -of=dext $(LTO)

$(DOCS): $(patsubst docs/%.html,source/%.d,$@) makefile
	$(COMPILER) $(patsubst docs/%.html,source/%.d,$@) -c -Df$@ -of$(patsubst docs/%.html,out/%.o,$@) $(DLANG_FLAGS)

$(OBJS): $(patsubst out/%.o,source/%.d,$@) makefile
	$(COMPILER) $(patsubst out/%.o,source/%.d,$@) -c -of$@ $(DLANG_FLAGS)

.PHONY: clean
clean:
	rm -rf dext out docs


STAGE ?= 3

BOOT ?= bins/boot.bc

HOST ?= C

VM ?= bin/minivm

DEP_C = bin/c-host
DEP_ = .dummy

default: bin/stage$(STAGE).bc

pgo-llvm%: .dummy
	$(MAKE) minivm/minivm
	./minivm/minivm bins/boot.bc bench/fib.paka -o out.bc
	$(MAKE) -C minivm $@ PGO='./minivm ../out.bc 35' OPT='$(OPT)'

bin/c-host: .dummy
	mkdir -p bin
	$(MAKE) -C minivm minivm
	cp minivm/minivm bin/minivm

STAGE_N=$(VM) $$LAST src/main.paka -o $$NEXT

bin/stage%.bc: $(DEP_$(HOST))
	@LAST=$(BOOT); for i in $$(seq 1 $(@:bin/stage%.bc=%)); do NEXT=bin/stage$$i.bc; echo $(STAGE_N); $(STAGE_N); LAST=$$NEXT; done

clean: .dummy
	$(MAKE) -C minivm clean
	: rm -r bin

.dummy:

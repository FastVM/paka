
BOOT ?= bins/boot.bc

COSMO ?= 0

FORMAT = bc

HOST ?= C

VM ?= bin/minivm

DEP_C = bin/c-host

default: bin/stage3.bc

bin/c-host: .dummy
	mkdir -p bin
	$(MAKE) -C minivm -f makefile minivm
	cp minivm/minivm bin/minivm

STAGE_N=$(VM) $$LAST src/main.paka -o $$NEXT

bin/stage%.bc: $(DEP_$(HOST))
	@LAST=$(BOOT); for i in $$(seq 1 $(@:bin/stage%.bc=%)); do NEXT=bin/stage$$i.bc; echo $(STAGE_N); $(STAGE_N); LAST=$$NEXT; done

clean: .dummy
	$(MAKE) -C minivm clean
	: rm -r bin

.dummy:

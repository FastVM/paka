
BOOT ?= bins/boot.bc

COSMO ?= 0

VM_0 = ./bin/minivm
VM_1 = ./bin/minivm.com

VM ?= $(VM_$(COSMO))

FORMAT = bc

default: bin/stage3.bc

./bin/minivm.com: minivm/vm minivm/main
	mkdir -p bin
	$(MAKE) -C minivm minivm.com
	cp minivm/minivm.com $@

./bin/minivm: minivm/vm minivm/main
	mkdir -p bin
	$(MAKE) -C minivm
	cp minivm/minivm $@

bin/stage1.bc: $(VM) src/main.paka
	mkdir -p bin
	$(VM) $(BOOT) src/main.paka -o $@

bin/stage2.bc: bin/stage1.bc
	$(VM) $^ src/main.paka -o $@

bin/stage3.bc: bin/stage2.bc
	$(VM) $^ src/main.paka -o $@

bin/stage4.bc: bin/stage3.bc
	$(VM) $^ src/main.paka -o $@

bin/stage5.bc: bin/stage4.bc
	$(VM) $^ src/main.paka -o $@

STAGE_N=$(VM) $$LAST src/main.paka -o $$NEXT

bin/stage%.bc: $(VM)
	@LAST=$(BOOT); for i in $$(seq 1 $(@:bin/stage%.bc=%)); do NEXT=bin/stage$$i.bc; echo $(STAGE_N); $(STAGE_N); LAST=$$NEXT; done

clean: .dummy
	$(MAKE) -C minivm clean
	: rm -r bin

.dummy:



BOOT ?= bins/boot.bc

COSMO ?= 0

VM_0 = ./bin/minivm
VM_1 = ./bin/minivm.com

VM ?= $(VM_$(COSMO))

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
	$(VM) $(BOOT) src/main.paka -o $@ -l bc

bin/stage2.bc: bin/stage1.bc
	$(VM) bin/stage1.bc src/main.paka -o $@ -l bc

bin/stage3.bc: bin/stage2.bc
	$(VM) bin/stage2.bc src/main.paka -o $@ -l bc

clean: .dummy
	$(MAKE) -C minivm clean
	rm -r bin

.dummy:


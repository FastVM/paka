
BOOT ?= bins/boot.bc

COSMO ?= 0

VM_0 = ./bin/minivm
VM_1 = ./bin/minivm.com

VM ?= $(VM_$(COSMO))

default: bin/stage3

./bin/minivm.com: minivm/vm minivm/main
	mkdir -p bin
	$(MAKE) -C minivm minivm.com
	cp minivm/minivm.com $@

./bin/minivm: minivm/vm minivm/main
	mkdir -p bin
	$(MAKE) -C minivm
	cp minivm/minivm $@

bin/stage1: $(VM) src/main.paka
	mkdir -p bin
	$(VM) $(BOOT) src/main.paka -o $@

bin/stage2: bin/stage1
	$(VM) bin/stage1 src/main.paka -o $@

bin/stage3: bin/stage2
	$(VM) bin/stage2 src/main.paka -o $@

clean: .dummy
	$(MAKE) -C minivm clean
	rm -r bin

.dummy:


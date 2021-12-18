
BOOT ?= bins/boot.vm

COSMO ?= 0

VM_0 = ./bin/minivm
VM_1 = ./bin/minivm.com

VM ?= $(VM_$(COSMO))

default: bin/stage3.vm

./bin/minivm.com: minivm/vm minivm/main
	mkdir -p bin
	$(MAKE) -C minivm minivm.com
	cp minivm/minivm.com $@

./bin/minivm: minivm/vm minivm/main
	mkdir -p bin
	$(MAKE) -C minivm
	cp minivm/minivm $@

bin/stage1.vm: $(VM) src/main.paka
	mkdir -p bin
	$(VM) $(BOOT) src/main.paka -o $@

bin/stage2.vm: bin/stage1.vm
	$(VM) bin/stage1.vm src/main.paka -o $@

bin/stage3.vm: bin/stage2.vm
	$(VM) bin/stage2.vm src/main.paka -o $@

clean: .dummy
	$(MAKE) -C minivm clean
	rm -r bin

.dummy:


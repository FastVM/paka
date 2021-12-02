
BOOT ?= bins/boot.bc
VM ?= ./bin/minivm

default: bin/stage3

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


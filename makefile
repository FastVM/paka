
BOOT ?= bins/build9.bc

default: bin/stage3

bin/minivm: minivm
	$(MAKE) -C minivm
	mkdir -p bin
	cp minivm/minivm bin/minivm

bin/stage1: bin/minivm
	./bin/minivm $(BOOT) src/paka.paka -o $@

bin/stage2: bin/stage1
	./bin/minivm bin/stage1 src/paka.paka -o $@

bin/stage3: bin/stage2
	./bin/minivm bin/stage2 src/paka.paka -o $@

clean: .dummy
	$(MAKE) -C minivm clean
	rm -r bin

.dummy:


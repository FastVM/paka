
BOOT ?= bins/build4.bc

default: stage3

bin/minivm: minivm
	$(MAKE) -C minivm --no-print-directory
	mkdir -p bin
	cp minivm/bin/minivm bin/minivm

stage1 bin/stage1: bin/minivm
	./bin/minivm $(BOOT) src/paka.paka
	mv exec.bc bin/stage1

stage2 bin/stage2: bin/stage1
	./bin/minivm bin/stage1 src/paka.paka
	mv exec.bc bin/stage2

stage3 bin/stage3: bin/stage2
	./bin/minivm bin/stage2 src/paka.paka
	mv exec.bc bin/stage3

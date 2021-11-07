
BOOT ?= bins/build8.bc

default: stage3

bin/minivm: minivm
	$(MAKE) -C minivm OPT="$(OPT)"
	mkdir -p bin
	cp minivm/minivm bin/minivm

stage1 bin/stage1: bin/minivm
	./bin/minivm $(BOOT) src/paka.paka
	mv exec.bc bin/stage1

stage2 bin/stage2: stage1
	./bin/minivm bin/stage1 src/paka.paka
	mv exec.bc bin/stage2

stage3 bin/stage3: stage2
	./bin/minivm bin/stage2 src/paka.paka
	mv exec.bc bin/stage3

clean: .dummy
	$(MAKE) -C minivm clean
	rm -r bin

.dummy:


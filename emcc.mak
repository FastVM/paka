NODE = node
PWD != pwd
FIND_FILES != find bins lang src test -type f
FILES = bench/tree.paka bench/fib.paka $(FIND_FILES)

EFLAGS += $(foreach FILE,$(FILES),--embed-file $(PWD)/$(FILE)@$(FILE)) 
EFLAGS += -s ASSERTIONS=1 -s WASM=1 -s WASM_BIGINT=1 -s ALLOW_MEMORY_GROWTH=1 -s SINGLE_FILE=1

CFLAGS += -DVM_MEM_MAX='1000*1000*100'

CFLAGS += $(EFLAGS)
LFLAGS += $(EFLAGS)

default: .dummy
	mkdir -p bin
	emmake $(MAKE) -C minivm OUT=minivm.js OPT=-O3 CFLAGS='$(CFLAGS)' LFLAGS='$(LFLAGS)'
	cp minivm/minivm.js bin/minivm.js

.dummy:

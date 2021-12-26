NODE = node
PWD != pwd
FIND_FILES != find bins lang -type f
FILES = bench/tree.paka bench/fib.paka $(FIND_FILES)

EFLAGS += $(foreach FILE,$(FILES),--embed-file $(PWD)/$(FILE)@$(FILE)) 
EFLAGS += -s ALLOW_MEMORY_GROWTH=1
EFLAGS += -s ASSERTIONS=0
EFLAGS += -s SINGLE_FILE=1
EFLAGS += -s WASM=1
# EFLAGS += -s ASYNCIFY=1

CFLAGS += -DVM_MEM_MAX='1000*1000*50'

CFLAGS += $(EFLAGS)
LFLAGS += $(EFLAGS)

default: .dummy
	mkdir -p bin
	emmake $(MAKE) -C minivm VM_API=1 OUT=minivm.js OPT='-O3 $(OPT)' CFLAGS='$(CFLAGS)' LFLAGS='$(LFLAGS)'
	cp minivm/minivm.js bin/minivm.js

.dummy:

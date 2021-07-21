define PYCMD
import time
print(repr(time.time()))
endef

watch: dummy
	@nodemon --quiet

build: dummy
	@time $(MAKE)

dummy:
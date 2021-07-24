UNZIP=unzip -oq

all: cross-platform

cosmopolitan.zip:
	wget https://justine.lol/cosmopolitan/cosmopolitan.zip

cosmopolitan: cosmopolitan.zip
	$(UNZIP) cosmopolitan.zip

cross-platform: cosmopolitan
	gcc --std=gnu11 -g -Ofast -static -fno-pie -no-pie -mno-red-zone -nostdlib -nostdinc \
		-fno-omit-frame-pointer -pg -mnop-mcount \
		-o bin/minivm.com.dbg minivm.c main.c -Wl,--gc-sections -fuse-ld=bfd \
		-Wl,-T,ape.lds -include cosmopolitan.h crt.o ape.o cosmopolitan.a -DVM_USE_COSMO
	objcopy -S -O binary bin/minivm.com.dbg bin/minivm.com

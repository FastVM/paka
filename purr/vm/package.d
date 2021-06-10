module purr.vm;

import purr.vm.bytecode;
import purr.io;

import core.memory;
import core.stdc.stdlib;

VM* vm;

static this()
{
    vm = cast(VM*) GC.calloc(VM.sizeof);
    int lalloc = (1 << 24);
    vm.linear = cast(void*) GC.calloc(lalloc);
    size_t falloc = lalloc / 256 * Frame.sizeof;
    vm.frames = cast(Frame*) GC.calloc(falloc);
}

void run(Bytecode func)
{
    GC.disable;
    vm_run(vm, func, null);
    GC.enable;
}

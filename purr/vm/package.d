module purr.vm;

import purr.vm.bytecode;
import std.stdio;

import core.memory;
import core.stdc.stdlib;

void run(Bytecode func) {
    GC.disable;
    vm_run(func);
    GC.enable;
}

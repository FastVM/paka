module purr.vm;

import purr.vm.bytecode;

import core.memory;
import core.stdc.stdlib;

void run(void[] func) {
    GC.disable;
    vm_run(func.ptr);
    GC.enable;
}

void vcompile(void[] func) {
    GC.disable;
    vm_bfc_compile(func.ptr);
    GC.enable;
}

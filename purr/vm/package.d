module purr.vm;

import purr.vm.bytecode;

import core.memory;
import core.stdc.stdlib;

extern (C) void vm_backend_bfasm(void* func);
extern (C) void vm_backend_js(void* func);

void run(void[] func) {
    GC.disable;
    vm_run(func.ptr);
    GC.enable;
}

void compile(string lang: "bf")(void[] func) {
    GC.disable;
    vm_backend_bfasm(func.ptr);
    GC.enable;
}

void compile(string lang: "js")(void[] func) {
    GC.disable;
    vm_backend_js(func.ptr);
    GC.enable;
}

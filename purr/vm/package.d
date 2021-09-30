module purr.vm;

import purr.vm.bytecode;

import std.string;
import std.stdio;

import core.memory;
import core.stdc.stdlib;


extern (C) char* vm_backend_bf(void* func);
extern (C) char* vm_backend_js(void* func, immutable(char) *jstype="node".ptr);
extern (C) char* vm_backend_lua(void* func);

void run(void[] func) {
    GC.disable;
    vm_run(func.ptr);
    GC.enable;
}

void compile(string lang: "bf")(void[] func) {
    GC.disable;
    vm_backend_bf(func.ptr);
    GC.enable;
}

char[] compile(string lang: "lua")(void[] func) {
    GC.disable;
    char* got = vm_backend_lua(func.ptr);
    char[] src = got.fromStringz.dup;
    free(got);
    GC.enable;
    return src;
}

char[] compile(string lang: "node")(void[] func) {
    GC.disable;
    char* got = vm_backend_js(func.ptr, "node".ptr);
    char[] src = got.fromStringz.dup;
    free(got);
    GC.enable;
    return src;
}


char[] compile(string lang: "v8")(void[] func) {
    GC.disable;
    char* got = vm_backend_js(func.ptr, "v8".ptr);
    char[] src = got.fromStringz.dup;
    free(got);
    GC.enable;
    return src;
}

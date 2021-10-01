module purr.vm;

import purr.vm.bytecode;

import std.string;
import std.stdio;

import core.memory;
import core.stdc.stdlib;


void run(void[] func) {
    GC.disable;
    vm_run(func.ptr);
    GC.enable;
}
module purr.vm;

import purr.vm.bytecode;
import purr.bc.opt;

import std.string;
import std.stdio;

import core.memory;
import core.stdc.stdlib;

void run(void[] func) {
    vm_run(func.ptr);
}
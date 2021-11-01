module purr.vm.state;

import purr.vm.bytecode;

import std.string;
import std.stdio;

import core.memory;
import core.stdc.stdlib;

void run(uint[] func, State *state) {
    vm_run(state, func.length, func.ptr);
}
module purr.vm.state;

import purr.vm.bytecode;

import std.string;
import std.stdio;

import core.memory;
import core.stdc.stdlib;

__gshared State* state;

shared static this() {
    state = vm_state_new();
}

shared static ~this() {
    vm_state_del(state);
}

void run(void[] func) {
    vm_run(state, func.length, func.ptr);
}
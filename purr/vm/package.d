module purr.vm;

import optimize.bytecode;

import std.string;
import std.stdio;

import core.memory;
import core.stdc.stdlib;

void run(void[] func) {
    vm_run(func.ptr);
}
module purr.vm.state;

import std.stdio: writeln;
import purr.vm.bytecode: vm_run, State;

void run(uint[] func, State *state) {
    vm_run(state, func.length, func.ptr);
}
module purr.vm.state;

import purr.vm.bytecode: vm_run, State;

void run(uint[] func, State *state) {
    vm_run(state, func.length, func.ptr);
}
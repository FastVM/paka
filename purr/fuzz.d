module purr.fuzz;

version(Fuzz):

import core.runtime;

import std.stdio;
import purr.err;

import purr.srcloc;
import purr.ast.ast;
import purr.ast.repl;
import purr.ast.walk;
import purr.vm.bytecode;
import purr.vm.state;
import purr.parse;

// extern(C) int LLVMFuzzerTestOneInput(const(void*) data, size_t size) {
//     Runtime.initialize;
//     string code = (cast(char*) data)[0..size].dup;
//     try {
//         State* state = vm_state_new();
//         Node[] nodes;
//         SrcLoc src = SrcLoc(1, 1, "__main__", code);
//         Node node = nodes.replify(src.parse("paka"));
//         Walker walker = new Walker;
//         walker.walkProgram(node);
//         run(walker.bytecode, state);
//         vm_state_del(state);
//     } catch (Problem p) {}
//     return 0;
// }

// ext
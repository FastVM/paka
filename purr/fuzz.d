module purr.fuzz;

import core.runtime;

version(Fuzz):

import std.stdio;
import purr.err;

import purr.srcloc;
import purr.ast.ast;
import purr.ast.walk;
import ext.paka.parse.parse;

version(Fuzz):

extern(C) int LLVMFuzzerTestOneInput(const(void*) data, size_t size) {
	Runtime.initialize;
	string code = (cast(char*) data)[0..size].dup;
	try {
		SrcLoc loc = SrcLoc(1, 1, "__main__", code);
		Node node = loc.parseUncached;  
        Walker walker = new Walker;
        walker.walkProgram(node);
		uint[] bc = walker.bytecode;
	} catch (Problem p) {}
	return 0;
}

// ext
module purr.fuzz;

import core.runtime;

version(Fuzz):

import std.stdio;
import purr.err;

import purr.srcloc;
import purr.ast.ast;
import purr.ast.walk;
import ext.paka.parse.parse;
import purr.bc.parser;
import purr.bc.opt;

extern(C) int LLVMFuzzerTestOneInput(const(void*) data, size_t size) {
	Runtime.initialize;
	string code = (cast(char*) data)[0..size].dup;
	try {
		SrcLoc loc = SrcLoc(1, 1, "__main__", code);
		Node node = loc.parseUncached;  
        Walker walker = new Walker;
        walker.walkProgram(node);
		void[] bc = walker.bytecode;
		assert(bc.validate == bc);
		writeln(code);
		// writeln(node);
		// writeln();
	} catch (Problem p) {}
	return 0;
}

// extern(C) int LLVMFuzzerTestOneInput(const(void*) data, size_t size) {
// 	Runtime.initialize;
// 	void[] bc = data[0..size].dup; 
// 	try {
// 		assert(bc.validate == bc);
// 	} catch (Problem p) {}
// 	return 0;
// }

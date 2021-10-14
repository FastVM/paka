module purr.bc.opt;

import std.stdio;

import purr.bc.instr;
import purr.bc.parser;
import purr.bc.writer;
import purr.bc.locs;

void[] optimize(void[] code) {
	Instr[] instrs = code.parse;
	foreach (instr; instrs) {
		writeln(instr);
	}
	// int[][int] branches = instrs.branches;
	// writeln(branches);
	void[] bytecode = instrs.toBytecode;
	return code;
}

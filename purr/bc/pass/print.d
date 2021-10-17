module purr.bc.pass.print;

import std.algorithm;
import std.stdio;

import purr.bc.instr;
import purr.bc.locs;
import purr.bc.opt;
import purr.vm.bytecode;

static this() {
	"print".set!Print;
}

class Print : Optimizer {
	this(Instr[] instrs) {
		super(instrs);
	}

	override void impl() {
		if (toplevel) {
			writeln(program);
		}
	}
}
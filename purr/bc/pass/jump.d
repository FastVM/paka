module purr.bc.pass.jump;

import std.algorithm;
import std.stdio;

import purr.bc.instr;
import purr.bc.locs;
import purr.bc.opt;
import purr.vm.bytecode;

static this() {
	"jump".set!Print;
}

class Print : Optimizer {
	this(Instr[] instrs) {
		super(instrs);
	}

	override void impl() {
		foreach (ref block; program.blocks) {
			if (block.instrs[$-1].op == Opcode.jump_always) {
				Location loc = block.instrs[$-1].args[0].value.location;
				foreach (ref target; program.blocks) {
					if (target.firstOffset == loc.loc) {
						block.instrs[$-1].keep = false;
						foreach (ref instr; target.instrs) {
							block.instrs ~= instr.copy;
						}
						if (target.next !is null) {
							block.instrs ~= Instr(Opcode.jump_always, Location(target.next.firstOffset));
						}
						block.next = target.next;
					}
				}
			}
		}
	}
}
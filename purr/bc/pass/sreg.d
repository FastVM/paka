module purr.bc.pass.sreg;

import std.algorithm;
import std.stdio;
import std.math;

import purr.bc.instr;
import purr.bc.locs;
import purr.bc.opt;
import purr.vm.bytecode;

static this() {
	"sreg".set!StoreReg;
}

class StoreReg : Optimizer {
	this(Instr[] instrs) {
		super(instrs);
	}

	void removeDead(ubyte[] usedRegs, Block block) {
		foreach (ref instr; block.instrs) {
			Register outReg;
			if (instr.op == Opcode.store_int) {
				outReg = cast(Register) instr.args[0];
			}
			if (instr.op == Opcode.store_byte) {
				outReg = cast(Register) instr.args[0];
			}
			if (instr.op == Opcode.store_reg) {
				outReg = cast(Register) instr.args[0];
			}
			if (outReg !is null && !usedRegs.canFind(outReg.reg)) {
				instr.keep = false;				
			}
		}
	}

	void markInstr(ref ubyte[] usedRegs, Instr instr) {
		int start = 0;
		if (instr.op == Opcode.store_int || instr.op == Opcode.store_byte || instr.op == Opcode.store_reg) {
			start = 1;
		}
		foreach (arg; instr.args[start..$]) {
			if (Register reg = cast(Register) arg) {
				usedRegs ~= reg.reg;
			}
			if (Call call = cast(Call) arg) {
				foreach (reg; call.regs) {
					usedRegs ~= reg;
				}
			}
		}
	}

	override void impl() {
		ubyte[] usedRegs;
		foreach (block; program.blocks) {
			foreach (instr; block.instrs) {
				markInstr(usedRegs, instr);
			}
		}
		foreach (block; program.blocks) {
			removeDead(usedRegs, block);
		}
	}
}
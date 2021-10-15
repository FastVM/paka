module purr.bc.reg;

import std.algorithm;

import purr.vm.bytecode;
import purr.bc.instr;

int[] usedRegs(Instr[] instrs) {
	int[] regs;
	int depth = 0;
	Instr[] sub;
	foreach (instr; instrs) {
		if (depth == 0) {
			foreach (arg; instr.args) {
				if (Register reg = cast(Register) arg) {
					if (!regs.canFind(reg.reg)) {
						regs ~= reg.reg;
					}
				}
			}
		}
		if (instr.op == Opcode.store_fun) {
			depth += 1;
		}
		if (instr.op == Opcode.fun_done) {
			depth -= 1;
		}
	}
	return regs;
}

int[][] allUsedRegs(Instr[] instrs) {
	int[][] allRegs = [usedRegs(instrs)];
	int depth = 0;
	Instr[] sub;
	foreach (instr; instrs) {
		if (instr.op == Opcode.fun_done) {
			depth -= 1;
			if (depth == 0) {
				allRegs ~= usedRegs(sub);
			}
		}
		if (depth > 0) {
			sub ~= instr;
		}
		if (instr.op == Opcode.store_fun) {
			depth += 1;
		}
	}
	return allRegs;
}

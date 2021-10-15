module purr.bc.pass.mathfold;

import std.algorithm;
import std.stdio;
import std.math;

import purr.bc.instr;
import purr.bc.locs;
import purr.bc.opt;
import purr.vm.bytecode;

static this() {
	"fold".set!Fold;
}

class Fold : Optimizer {
	this(Instr[] instrs) {
		super(instrs);
	}

	Instr foldInstr(string op)(ref int[ubyte] constRegs, Argument outRegArg, Argument inRegArg, Argument valArg) {
		Register outReg = cast(Register) outRegArg;
		Register argReg = cast(Register) inRegArg;
		int num;
		if (Integer inum = cast(Integer) valArg) {
			num = inum.val;
		}
		if (Byte bnum = cast(Byte) valArg) {
			num = cast(int) bnum.val;
		}
		if (Register reg = cast(Register) valArg) {
			if (int *refValue = reg.reg in constRegs) {
				num = *refValue;
			} else {
				return null;
			}
		}
		if (int *refValue = argReg.reg in constRegs) {
			double res = mixin(`cast(double) *refValue` ~ op ~ `cast(double) num`);
			if (res % 1 == 0 && 0 <= res && res < 256) {
				return new Instr(Opcode.store_byte, [outReg, new Byte(cast(ubyte) res)]);
			}
			if (res % 1 == 0 && res.abs < 2L ^^ 31) {
				return new Instr(Opcode.store_int, [outReg, new Integer(cast(int) res)]);
			}
		}
		return null;
	}

	void foldMath(Block block) {
		redoPass: while (true) {
			int[ubyte] constRegs;
			storeHere: foreach (ref instr; block.instrs) {
				if (instr.op == Opcode.store_int) {
					Register reg = cast(Register) instr.args[0];
					Integer num = cast(Integer) instr.args[1];
					constRegs[reg.reg] = num.val;
					continue storeHere;
				}
				if (instr.op == Opcode.store_byte) {
					Register reg = cast(Register) instr.args[0];
					Byte num = cast(Byte) instr.args[1];
					constRegs[reg.reg] = num.val;
					continue storeHere;
				}
				if (instr.op == Opcode.store_reg) {
					Register outReg = cast(Register) instr.args[0];
					Register inReg = cast(Register) instr.args[1];
					if (int *refValue = inReg.reg in constRegs) {
						if (0 <= *refValue && *refValue < 256) {
							instr = new Instr(Opcode.store_byte, [outReg, new Byte(cast(ubyte) *refValue)]);
						} else {
							instr = new Instr(Opcode.store_int, [outReg, new Integer(*refValue)]);
						}
						continue redoPass;
					}
				}
				bool redo = false;
				void fold(string op, Args...)(Args args) {
					if (!redo) {
						if (Instr res = foldInstr!op(constRegs, args)) {
							redo = true;
							instr = res;
						}
					}
				}
				if (instr.op == Opcode.inc_num || instr.op == Opcode.inc) {
					fold!"+"(instr.args[0], instr.args[0], instr.args[1]);
				}
				if (instr.op == Opcode.dec_num || instr.op == Opcode.dec) {
					fold!"-"(instr.args[0], instr.args[0], instr.args[1]);
				}
				if (instr.op == Opcode.add_num || instr.op == Opcode.add) {
					fold!"+"(instr.args[0], instr.args[1], instr.args[2]);
				}
				if (instr.op == Opcode.sub_num || instr.op == Opcode.sub) {
					fold!"-"(instr.args[0], instr.args[1], instr.args[2]);
				}
				if (instr.op == Opcode.mul_num || instr.op == Opcode.mul) {
					fold!"*"(instr.args[0], instr.args[1], instr.args[2]);
				}
				if (instr.op == Opcode.div_num || instr.op == Opcode.div) {
					fold!"/"(instr.args[0], instr.args[1], instr.args[2]);
				}
				if (instr.op == Opcode.mod_num || instr.op == Opcode.mod) {
					fold!"%"(instr.args[0], instr.args[1], instr.args[2]);
				}
				if (redo) {
					continue redoPass;
				}
			}
			break redoPass;
		}
	}

	void foldMathBlocks() {
		foreach (block; program.blocks) {
			foldMath(block);
		}
	}

	override void impl() {
		foldMathBlocks();
	}
}
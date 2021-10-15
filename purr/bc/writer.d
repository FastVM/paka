module purr.bc.writer;

import std.conv;
import std.stdio;
import std.algorithm;

import purr.vm.bytecode;
import purr.bc.instr;

void put(Type)(ref void[] buf, Type val) {
	buf ~= (cast(void*)&val)[0..Type.sizeof];
}

void bufWrite(ref void[] buf, Instr instr, ref int[int] updateOffsets, ref int[] putOffsets) {
	updateOffsets[instr.offset] = cast(int) buf.length;
	buf.put(instr.op);
	foreach (arg; instr.args) {
		if (Register reg = cast(Register) arg) {
			buf.put(cast(ubyte) reg.reg);
		}
		if (Byte byte_ = cast(Byte) arg) {
			buf.put(cast(ubyte) byte_.val);
		}
		if (Integer int_ = cast(Integer) arg) {
			buf.put(cast(int) int_.val);
		}
		if (Location loc = cast(Location) arg) {
			putOffsets ~= cast(int) buf.length;
			buf.put(cast(int) loc.loc);
		}
		if (Call call = cast(Call) arg) {
			buf.put(cast(ubyte) call.regs.length);
			foreach (reg; call.regs) {
				buf.put(cast(ubyte) reg);
			}
		}
		if (Function func = cast(Function) arg) {
			updateOffsets[func.instrs[0].offset - 1] = cast(int) buf.length;
			buf.put(cast(ubyte) func.nregs);
			foreach (subInstr; func.instrs) {
				buf.bufWrite(subInstr, updateOffsets, putOffsets);
			}
			buf.put(Opcode.fun_done);
		}
	}
}

void[] toBytecode(Instr[] instrs) {
	void[] ret;
	int[int] updateOffsets;
	int[] putOffsets;
	foreach (instr; instrs) {
		ret.bufWrite(instr, updateOffsets, putOffsets);
	}
	updateOffsets[0] = 0;
	foreach (where; putOffsets) {
		int *ptr = cast(int*) ret[where..where+int.sizeof].ptr;
		*ptr = updateOffsets[*ptr];
	}
	ret.put(Opcode.exit);
	return ret;
}

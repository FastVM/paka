module purr.bc.writer;

import std.conv;
import std.stdio;

import purr.vm.bytecode;
import purr.bc.instr;

void put(Type)(ref void[] buf, Type val) {
	buf ~= (cast(void*)&val)[0..Type.sizeof];
}

void bufWrite(ref void[] buf, Instr instr) {
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
			buf.put(cast(int) loc.loc);
		}
		if (Call call = cast(Call) arg) {
			buf.put(cast(ubyte) call.regs.length);
			foreach (reg; call.regs) {
				buf.put(cast(ubyte) reg);
			}
		}
	}
}

void[] toBytecode(Instr[] instrs) {
	void[] ret;
	foreach (instr; instrs) {
		ret.bufWrite(instr);
	}
	return ret;
}

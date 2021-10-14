module purr.bc.parse;

import std.conv;
import std.stdio;

import purr.vm.bytecode;
import purr.bc.format;
import purr.bc.instr;

Type read(Type)(ref void[] code) {
	Type ret = *cast(Type*) code.ptr;
	code = code[Type.sizeof..$];
	return ret;
}

Argument readFmt(ref void[] code, char c) {
	final switch (c) {
	case 'r':
		return new Register(code.read!ubyte);
	case 'b': 
		return new Byte(code.read!ubyte);
	case 'i':
		return new Integer(code.read!int);
	case 'j':
		return new Location(code.read!int);
	case 'c':
		ubyte num = code.read!ubyte;
		ubyte[] regs;
		foreach (i; 0..num) {
			regs ~= code.read!ubyte;
		}
		return new Call(regs);
	}
}

Instr readInstr(ref void[] code) {
	Opcode op = code.read!Opcode;
	Argument[] args;
	Format opFmt = format[op];
	foreach (spec; opFmt) {
		args ~= code.readFmt(spec);
	}
	return new Instr(op, args);
}

Instr[] parse(void[] code) {
	Instr[] ret;
	size_t len0 = code.length;
	while (code.length != 0) {
		size_t len = code.length;
		Instr instr = code.readInstr;
		instr.index = cast(int) (len0 - len);
		ret ~= instr;
	}
	return ret;
}

module purr.bc.instr;

import std.conv;
import std.array;
import std.algorithm;
import purr.vm.bytecode;

class Argument {}

class Register : Argument {
	ubyte reg;

	this(ubyte reg_) {
		reg = reg_;
	}

	override string toString() {
		return "r" ~ reg.to!string;
	}
}

class Byte : Argument {
	ubyte val;

	this(ubyte val_) {
		val = val_;
	}

	override string toString() {
		return val.to!string;
	}
}

class Integer : Argument {
	int val;

	this(int val_) {
		val = val_;
	}

	override string toString() {
		return val.to!string;
	}
}

class Location : Argument {
	int loc;

	this(int loc_) {
		loc = loc_;
	}

	override string toString() {
		return "@" ~ loc.to!string;
	}
}

class Call : Argument {
	ubyte[] regs;
	
	this(ubyte[] regs_) {
		regs = regs_;
	}

	override string toString() {
		return "(" ~ regs.map!(x => 'r' ~ x.to!string).join(", ") ~ ")";
	}
}

string indent(string src) {
	string ret = "  ";
	foreach (c; src) {
		if (c == '\n') {
			ret ~= "\n  ";
		} else {
			ret ~= c;
		}
	}
	return ret;
}

class Function : Argument {
	Instr[] instrs;
	ubyte nregs;

	this(ubyte nregs_, Instr[] instrs_) {
		nregs = nregs_;
		instrs = instrs_;
	}

	override string toString() {
		return "{\n" ~ instrs.instrsToString.indent ~ "}";
	}
}

class Instr {
	int offset;
	Opcode op;
	Argument[] args;
	bool outJump;
	bool inJump;
	bool keep = true;

	this(Opcode op_, Argument[] args_ = null) {
		op = op_;
		args = args_;
	}

	void opOpAssign(string op: "~", Type)(Type val) {
		args ~= cast(Argument) val;
	}

	override string toString() {
		if (args.length == 0) {
			return op.to!string;
		}
		return op.to!string ~ " " ~ args.to!string[1..$-1];
	}
}

string instrsToString(Instr[] instrs) {
	string ret;
	bool last = false;
	foreach (instr; instrs) {
		if (instr.inJump || last) {
			ret ~= instr.offset.to!string;
			ret ~= ":\n";
		}
		ret ~= "  ";
		ret ~= instr.to!string;
		ret ~= '\n';
		last = instr.outJump;
	}
	return ret;
}

module purr.bc.instr;

import purr.vm.bytecode;
import std.conv;

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
		return regs.to!string;
	}
}

class Instr {
	int index;
	Opcode op;
	Argument[] args;

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

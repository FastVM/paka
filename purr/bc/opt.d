module purr.bc.opt;

import std.stdio;
import std.algorithm;

import purr.bc.parser;
import purr.bc.writer;
import purr.bc.instr;
import purr.bc.locs;
import purr.bc.reg;
import purr.vm.bytecode;
import purr.err;

Instr readInstr(ref Instr[] instrs) {
	Instr ret = instrs[0];
	instrs = instrs[1..$];
	return ret;
}

class Blocks {
	Block[] blocks;
	
	this() {}

	static Blocks from(Instr[] instrs) {
		return Blocks.parse(instrs);
	}

	static Blocks parse(ref Instr[] instrs) {
		Blocks func = new Blocks;
		while (true) {
			Block block = Block.parse(instrs);
			func.blocks ~= block;
			if (instrs.length == 0) {
				break;
			}
		}
		foreach (index, block; func.blocks[0..$-1]) {
			if (block.usesNext) {
				block.next = func.blocks[index + 1];
			}
		}
		if (func.blocks[$-1].instrs[$-1].op != Opcode.exit) {
			func.blocks[0].startOffset = 1;
		}
		return func;
	}
	
	Instr[] instrs() {
		Instr[] instrs;
		this.getInstrs(instrs);
		return instrs;
	}

	void getInstrs(ref Instr[] outInstrs) {
		foreach (block; blocks) {
			block.getInstrs(outInstrs);
		}
	}

	override string toString() {
		Instr[] instrs;
		getInstrs(instrs);
		return instrsToString(instrs);
	}
}

class Block {
	Instr[] instrs;
	Block next;
	int startOffset = 0;

	this() {}

	static Block parse(ref Instr[] instrs) {
		Block block = new Block;
		Instr first = instrs.readInstr;
		block.instrs ~= first;
		if (first.outJump) {
			return block;
		}
		while (true) {
			if (instrs.length == 0) {
				break;
			}
			if (instrs[0].inJump) {
				break;
			}
			Instr instr = instrs.readInstr;
			block.instrs ~= instr;
			if (instr.outJump) {
				break;
			}
		}
		return block;
	}

	void getInstrs(ref Instr[] outInstrs) {
		foreach (instr; instrs) {
			outInstrs ~= instr;
		}
	}

	int firstOffset() {
		if (instrs.length != 0) {
			return instrs[0].offset + startOffset;
		}
		if (next !is null) {
			return next.firstOffset;
		}
		vmError("basic block has nowhere to go");
		assert(false);
	}

	bool usesNext() {
		return instrs[$-1].op != Opcode.exit && instrs[$-1].op != Opcode.ret;
	}

	override string toString() {
		Instr[] instrs;
		getInstrs(instrs);
		return instrsToString(instrs);
	}
}

class Optimizer {
	Blocks program;
	int[] blockScanned;
	Block[int] blocksByOffset;
	int[Block] blockRefCount;

	this(Instr[] instrs) {
		program = Blocks.parse(instrs);
	}

	void jumpCombineRef(Block block) {
		blockRefCount[block] += 1;
		if (!blockScanned.canFind(block.firstOffset)) {
			blockScanned ~= block.firstOffset;
			foreach (instr; block.instrs) {
				if (instr.op == Opcode.store_fun) {
					continue;
				}
				if (!instr.outJump) {
					continue;
				}
				foreach (arg; instr.args) {
					if (Location loc = cast(Location) arg) {
						jumpCombineRef(blocksByOffset[loc.loc]);
					}
				}
			}
			if (block.next !is null) {
				jumpCombineRef(block.next);
			}
		}
	}

	void jumpCombine() {
		foreach (block; program.blocks) {
			blocksByOffset[block.firstOffset] = block;
			blockRefCount[block] = 0;
		}
		jumpCombineRef(program.blocks[0]);
		Block[] oldBlocks = program.blocks;
		program.blocks = null;
		Block last = null;
		foreach (block; oldBlocks) {
			if (blockRefCount[block] != 0) {
				if (last !is null) {
					if (last.usesNext) {
						last.next = block;
					}
				}
				program.blocks ~= block;
				last = block;
			}
		}
		if (last !is null) {
			last.next = null;
		}
	}

	Instr[] instrs() {
		return program.instrs;
	}

	void opt(string pass) {
		foreach (block; program.blocks) {
			foreach (instr; block.instrs) {
				foreach (ref arg; instr.args) {
					if (Function func = cast(Function) arg) {
						Optimizer subOpt = new Optimizer(func.instrs);
						subOpt.opt(pass);
						func.instrs = subOpt.instrs;
					}
				}
			}
		}
		if (pass == "dce") {
			jumpCombine();
		}
	}
}

void[] optimize(void[] code, string pass) {
	Optimizer opt = new Optimizer(code.parse);
	opt.opt(pass);
	return opt.instrs.toBytecode;
}

void[] validate(void[] code) {
	return code.parse.toBytecode;
}

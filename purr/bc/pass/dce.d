module purr.bc.pass.dce;

import std.algorithm;

import purr.bc.instr;
import purr.bc.locs;
import purr.bc.opt;
import purr.vm.bytecode;

static this() {
	"dce".set!DCE;
}

class DCE : Optimizer {
	int[] blockScanned;
	Block[int] blocksByOffset;
	int[Block] blockRefCount;

	this(Instr[] instrs) {
		super(instrs);
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

	override void impl() {
		jumpCombine();
	}
}
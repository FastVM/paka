module purr.bc.pass.regalloc;

import std.algorithm;
import std.stdio;

import purr.bc.instr;
import purr.bc.locs;
import purr.bc.opt;
import purr.vm.bytecode;

static this() {
	"regalloc".set!RegAlloc;
}

class RegAlloc : Optimizer {
	int[ubyte] firstSeen;
	int[ubyte] lastSeen;
	ubyte[] pinnedRegs;

	this(Instr[] instrs) {
		super(instrs);
	}

	// if (Location loc = cast(Location) arg) {
	// 	if (loc.loc < instr.offset) {
	// 		foreach (index, ref lastSeen; lastSeen) {
	// 			if (firstSeen[index] < loc.loc && loc.loc < lastSeen[index]) {
	// 			}
	// 		}
	// 	}
	// }

	void calcBaseRanges() {
		foreach (block; program.blocks) {
			foreach (instr; block.instrs) {
				foreach (arg; instr.args) {
					if (Register reg = cast(Register) arg) {
						if (reg.reg !in firstSeen) {
							firstSeen[reg.reg] = instr.offset;
						}
						if (reg.reg !in lastSeen || instr.offset > lastSeen[reg.reg]) {
							lastSeen[reg.reg] = instr.offset;
						}
					}
					if (Call call = cast(Call) arg) {
						foreach (reg; call.regs) {
							if (reg !in firstSeen) {
								firstSeen[reg] = instr.offset;
							}
							if (reg !in lastSeen || instr.offset > lastSeen[reg]) {
								lastSeen[reg] = instr.offset;
							}
						}
					}
				}
			}
		}
		foreach (block; program.blocks) {
			foreach (instr; block.instrs) {
				foreach (arg; instr.args) {
					if (Location loc = cast(Location) arg) {
						if (loc.loc < instr.offset) {
							foreach (index, ref ls; lastSeen) {
								int fs = firstSeen[index];
								if (fs < loc.loc && loc.loc <= ls && ls < instr.offset) {
									ls = instr.offset;
								} 
							}
						}
					}
				}
			}
		}
	}

	void regAlloc() {
		bool[256] used;
		ubyte[ubyte] regs;
		foreach (arg; pinnedRegs) {
			used[arg] = true;
			regs[arg] = arg;
		}
		foreach (block; program.blocks) {
			foreach (instr; block.instrs) {
				foreach (oldReg, newReg; regs) {
					if (!pinnedRegs.canFind(oldReg) && lastSeen[oldReg] == instr.offset) {
						used[regs[cast(ubyte) oldReg]] = false;
					}
				}
				foreach (arg; instr.args) {
					if (Register reg = cast(Register) arg) {
						if (pinnedRegs.canFind(reg.reg)) {
							continue;
						}
						if (reg.reg !in regs) {
							foreach (index, ref isUsed; used) {
								if (!isUsed) {
									regs[reg.reg] = cast(ubyte) (index);
									isUsed = true;
									if (index >= nregs) {
										nregs = cast(ubyte) (index + 1);
									}
									break;
								}
							}
						}
						reg.reg = regs[reg.reg];
					}
					if (Call call = cast(Call) arg) {
						foreach (argno, reg; call.regs) {
							if (pinnedRegs.canFind(reg)) {
								continue;
							}
							if (reg !in regs) {
								foreach (index, ref isUsed; used) {
									if (!isUsed) {
										regs[reg] = cast(ubyte) (index);
										isUsed = true;
										if (index >= nregs) {
											nregs = cast(ubyte) (index + 1);
										}
										break;
									}
								}
							}
							call.regs[argno] = regs[reg];
						}
					}
				}
				foreach (oldReg, newReg; regs) {
					if (lastSeen[oldReg] == instr.offset) {
						regs.remove(cast(ubyte) oldReg);
					}
				}
			}
		}
	}

	void calcNumArgs() {
		int[] seen;
		foreach (block; program.blocks) {
			foreach (ref instr; block.instrs) {
				int start = 0;
				if (!instr.op.noOutputs) {
					start = 1;
					if (Register reg = cast(Register) instr.args[0]) {
						if (!seen.canFind(reg.reg)) {
							seen ~= reg.reg;
						}
					}
				}
				foreach (arg; instr.args[start..$]) {
					if (Register reg = cast(Register) arg) {
						if (!seen.canFind(reg.reg) && !pinnedRegs.canFind(reg.reg)) {
							pinnedRegs ~= reg.reg;
						}
					}
					if (Call call = cast(Call) arg) {
						foreach (reg; call.regs) {
							if (!seen.canFind(reg) && !pinnedRegs.canFind(reg)) {
								pinnedRegs ~= reg;
							}
						}
					}
				}
			}
		}
	}

	override void impl() {
		nregs = 0;
		calcNumArgs();
		calcBaseRanges();
		regAlloc();
	}
}
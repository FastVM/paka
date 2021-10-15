module purr.bc.locs;

import purr.bc.instr;

int[][int] branches(Instr[] instrs) {
	int[][int] ret;
	foreach (instr; instrs) {
		foreach (arg; instr.args) {
			if (Location loc = cast(Location) arg) {
				int to = loc.loc;
				if (int[]* val = instr.offset in ret) {
					*val ~= to;
				} else {
					ret[instr.offset] = [to];
				}
			}
		}
	}
	return ret;
}

int[] indexToOffset(Instr[] instrs) {
	int[] ret;
	foreach (instr; instrs) {
		ret ~= instr.offset;
	}
	return ret;
}

int[] offsetToIndex(Instr[] instrs) {
	int[] ret;
	int last = 0;
	foreach (index, instr; instrs) {
		while (ret.length < instr.offset) {
			ret ~= last;
		}
		last = cast(int) index;
		ret ~= last;
	}
	return ret;
}

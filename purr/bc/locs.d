module purr.bc.locs;

import purr.bc.instr;

int[][int] branches(Instr[] instrs) {
	int[][int] ret;
	foreach (indexLong, instr; instrs) {
		int index = cast(int) indexLong;
		foreach (arg; instr.args) {
			if (Location loc = cast(Location) arg) {
				int to = loc.loc;
				if (int[]* val = index in ret) {
					*val ~= to;
				} else {
					ret[index] = [to];
				}
			}
		}
	}
	return ret;
}

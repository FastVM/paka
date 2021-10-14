module purr.sys.first;

import std.stdio;
import purr.sys.obj;
import purr.sys.gc;

class State {
	Entry*[] owns;
	Memory *gc;

	this(Memory* gc_) {
		owns = null;
		gc = gc_;
	}
}

private extern(C) void vm_sys_mark(State state) {
	size_t head = 0;
	foreach (elem; state.owns) {
		if (elem !is null) {
			state.owns[head++] = elem;
			vm_gc_mark_ptr(state.gc, elem);
		}
	}
	state.owns.length = head;
}

private extern(C) State vm_sys_init(Memory* mem) {
	return new State(mem);
}

private extern(C) Value vm_syscall(State sys, Value arg) {
	return Value(0);
}

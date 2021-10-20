module purr.sys.gc;

import purr.sys.obj;

struct Memory {}

struct Entry {}

extern(C) {
	Entry* vm_gc_new(Memory* gc, size_t len, Value* values);
	size_t vm_gc_sizeof(Entry* ptr);
	Value vm_gc_get_index(Entry* ptr, size_t index);
	void vm_gc_set_index(Entry *ptr, size_t index, Value value);
	void vm_gc_mark_ptr(Memory* gc, Entry* ent);
}

Value arr(Memory* mem, Value[] arg) {
	return Value(vm_gc_new(mem, arg.length, arg.ptr));
}

Value arr(Arg)(Memory* mem, Arg[] arg) {
	Value[] vals;
	foreach (elem; arg) {
		vals ~= Value(arg);
	}
	return mem.arr(vals);
}

Value arr(Type)(Type arg, Memory* mem) {
	return mem.array(arg);
}

void arr(Type)(Type arg) {
	static assert(false, "no memory (Memory* mem) was passed as an argument");
}

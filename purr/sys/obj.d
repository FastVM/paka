module purr.sys.obj;

import std.conv;
import std.ascii;
import purr.sys.gc;

private alias Internal = void[8]; 

extern (C) {
	int vm_xobj_to_int(Internal obj);
	double vm_xobj_to_num(Internal obj);
	Entry* vm_xobj_to_ptr(Internal obj);
	int vm_xobj_to_fun(Internal obj);

	Internal vm_xobj_of_int(int obj);
	Internal vm_xobj_of_num(double obj);
	Internal vm_xobj_of_ptr(Entry* obj);
	Internal vm_xobj_of_fun(int obj);

	bool vm_xobj_is_num(Internal obj);
	bool vm_xobj_is_ptr(Internal obj);
}

struct Value {
	private Internal internal;
	
	this(Internal val) {
		internal = val;
	}

	this(Value other) {
		internal = other.internal;
	}

	this(int num) {
		internal = vm_xobj_of_int(num);
	}

	this(double num) {
		internal = vm_xobj_of_num(num);
	}

	this(Entry* ptr)
	{
		internal = vm_xobj_of_ptr(ptr);	
	}

	bool isNum() {
		return vm_xobj_is_num(internal);
	}

	bool isArray() {
		return vm_xobj_is_ptr(internal);
	}

	bool isStr() {
		if (!isArray) {
			return false;
		}
		foreach (chr; this) {
			if (!chr.isNum) {
				return false;
			}
			double n = chr.num;
			if (!to!char(chr.num % 256).isPrintable) {
				return false;
			}	
		}
		return true;
	}

	double num() {
		return vm_xobj_to_num(internal);
	}

	Entry *ptr() {
		return vm_xobj_to_ptr(internal);
	}

	string str() {
		string ret;
		foreach (chr; this) {
			ret ~= chr.num.to!char;
		}
		return ret; 
	}

	Value opIndex(size_t index) {
		return Value(vm_gc_get_index(this.ptr, index));
	}

	size_t length() {
		return vm_gc_sizeof(this.ptr);
	}

	int opApply(int delegate(Value) dg) {
		foreach (index; 0..this.length) {
			if (dg(this[index])) {
				return 1;
			}
		}
		return 0;
	}

	int opApply(int delegate(size_t, Value) dg) {
		foreach (index; 0..this.length) {
			if (dg(index, this[index])) {
				return 1;
			}
		}
		return 0;
	}

	string toString() {
		if (this.isArray) {
			string ret = "[";
			foreach (index, elem; this) {
				if (index != 0) {
					ret ~= ", ";
				}
				ret ~= elem.toString;
			}
			ret ~= "]";
			return ret;
		} else if (this.isNum) {
			return this.num.to!string;
		} else {
			return "?";
		}
	}

	bool opEquals(Value other) {
		return this.num == other.num;
	}

	int opCmp(Value other) {
		double lhs = this.num;
		double rhs = other.num;
		if (lhs < rhs) {
			return -1;
		}
		if (lhs == rhs) {
			return 0;
		}
		if (lhs > rhs) {
			return 1;
		}
		assert(false);
	}

	Value opUnary(string op)() {
		double rhs = this.num;
		double res = mixin(op ~ "rhs");
		return Value(res);
	}

	Value opBinary(string op)(Value other) {
		double lhs = this.num;
		double rhs = other.num;
		double res = mixin("lhs" ~ op ~ "rhs");
		return Value(res);
	}
}

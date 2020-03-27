module lisp.bytecode;

class Function {
    struct Lookup {
        ushort[string] byName;
        string[] byPlace;
        void set(string name, ushort us) {
            byName[name] = us;
            byPlace ~= name;
        }
        ushort define(string name) {
            ushort ret = cast(ushort) byPlace.length;
            set(name, ret);
            return ret;
        } 
        ushort opIndex(string name) {
            return byName[name];
        }
        string opIndex(ushort name) {
            return byPlace[name];
        }
    }
    struct Capture {
        ushort from;
        ushort to;
    }
    import lisp.dynamic: Dynamic, dynamic;
    Capture[] capture;
    Instr[] instrs;
    Dynamic[] constants;
    Function[] funcs;
    Lookup stab;
    Function parent;
    Dynamic* captured;
    size_t stackSize;
    this(){}
    this(Function other) {
        capture = other.capture;
        instrs = other.instrs;
        constants = other.constants;
        funcs = other.funcs;
        parent = other.parent;
        captured = other.captured;
        stackSize = other.stackSize;
    }
    ushort useName(string name) {
        import std.stdio: writeln;
        ushort* ret = name in stab.byName;
        if (ret !is null) {
            return *ret;
        }
        ushort ind = stab.define(name);
        capture ~= Capture(parent.useName(name), ind);
        return ind;
    }
    override string toString() {
        import std.conv: to;
        return "Function(" ~ instrs.to!string[1..$-1] ~ ")";
    }
}


enum Opcode: ushort {
    push,
    pop,
    call,
    func,
    load,
    store,
    retval,
    retnone,
    iftrue,
    jump,
} 

struct Instr {
    align(1):
    Opcode op;
    ushort value;
}
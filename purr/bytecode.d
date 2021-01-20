module purr.bytecode;

import purr.dynamic;
import purr.srcloc;
import purr.error;
import std.stdio;

class Function
{
    struct Lookup
    {
        uint[string] byName;
        string[] byPlace;
        Flags[] flagsByPlace;

        enum Flags {
            noFlags = 0,
            callImplicit = 1,
            noAssign = 2,
        }

        size_t length() {
            return byPlace.length;
        }

        void clear()
        {
            byName = null;
            byPlace = null;
        }

        void set(string name, uint us, Flags flags)
        {
            byName[name] = us;
            byPlace ~= name;
            flagsByPlace ~= flags;
        }

        uint define(string name, Flags flags = Flags.noFlags)
        {
            uint ret = cast(uint)(byPlace.length);
            set(name, ret, flags);
            return ret;
        }

        Flags flags(string name) {
            return flagsByPlace[byName[name]];
        }

        Flags flags(uint name) {
            return flagsByPlace[name];
        }

        uint opIndex(string name)
        {
            return byName[name];
        }

        string opIndex(T)(T name)
        {
            return byPlace[name];
        }

        immutable(uint[string]) byNameImmutable() {
            return cast(immutable(uint[string])) byName;
        }
    }

    struct Capture
    {
        uint from;
        bool is2;
        bool isArg;
        uint offset;
    }

    enum Flags : ubyte
    {
        isLocal = 1,
    }

    Capture[] capture = null;
    ubyte[] instrs = null;
    Span[] spans = null;
    Dynamic[] constants = null;
    Function[] funcs = null;
    Dynamic*[] captured = null;
    size_t stackSize = 0;
    int[size_t] stackAt = null;
    Dynamic[] self = null;
    string[] args = null;
    Function parent = null;
    Lookup stab;
    Lookup captab;
    Flags flags = cast(Flags) 0;

    this()
    {
    }

    this(Function other)
    {
        capture = other.capture;
        instrs = other.instrs;
        spans = other.spans;
        constants = other.constants;
        funcs = other.funcs;
        parent = other.parent;
        captured = other.captured;
        stackSize = other.stackSize;
        self = other.self.dup;
        args = other.args;
        stab = other.stab;
        captab = other.captab;
        flags = other.flags;
    }

    uint doCapture(string name)
    {
        uint* got = name in captab.byName;
        if (got !is null)
        {
            return *got;
        }
        foreach (argno, argname; parent.args) {
            if (argname == name) {
                uint ret = captab.define(name);
                capture ~= Capture(cast(uint) argno, false, true);
                return ret;
            }
        }
        Lookup.Flags flags = void;
        if (uint* found = name in parent.stab.byName)
        {
            capture ~= Capture(parent.stab.byName[name], false, false);
            flags = parent.stab.flags(name);
        }
        else if (name in parent.captab.byName)
        {
            capture ~= Capture(parent.captab.byName[name], true, false);
            flags = parent.captab.flags(name);
        }
        else
        {
            if (parent.parent is null)
            {
                throw new UndefinedException("name not found: " ~ name);
            }
            parent.doCapture(name);
            capture ~= Capture(parent.captab.byName[name], true, false);
            flags = parent.captab.flags(name);
        }
        uint ret = captab.define(name, flags);
        capture[$-1].offset = ret;
        return ret;
    }

    override string toString()
    {
        return "<function>";
    }
}

enum AssignOp : ubyte
{
    add,
    sub,
    mul,
    div,
    mod,
}

enum Opcode : ubyte
{
    // never generated
    nop,
    // stack ops
    push,
    pop,
    // subroutine
    sub,
    // bind not implmented yet
    bind,
    // call without spread
    call,
    // call with atleast 1 spread
    upcall,
    // cmp
    oplt,
    opgt,
    oplte,
    opgte,
    opeq,
    opneq,
    // build array
    array,
    // unpack into array
    unpack,
    // built table
    table,
    // index table or array
    index,
    // math ops (arithmatic)
    opneg,
    opadd,
    opsub,
    opmul,
    opdiv,
    opmod,
    // load from locals
    load,
    // load from captured
    loadc,
    // store to locals
    store,
    istore,
    // same but with operators like += and -=
    opstore,
    opistore,
    // return a value
    retval,
    // return no value
    retnone,
    // jump if true
    iftrue,
    // jump if false
    iffalse,
    // jump to index
    jump,
    // arg number
    argno,
    // all args as list
    args,
}

enum int[Opcode] opSizes = [
        // may change: call, array, targeta, table, upcall
        Opcode.nop : 0, Opcode.push : 1, Opcode.pop : -1, Opcode.sub : 1,
        Opcode.bind : -1, Opcode.oplt : -1, Opcode.opgt : -1, Opcode.oplte
        : -1, Opcode.opgte : -1, Opcode.opeq : -1, Opcode.opneq : -1,
        Opcode.unpack : 1, Opcode.index : -1, Opcode.opneg : 0, Opcode.opadd
        : -1, Opcode.opsub : -1, Opcode.opmul : -1, Opcode.opdiv : -1,
        Opcode.opmod : -1, Opcode.load : 1, Opcode.loadc : 1, Opcode.store : -1,
        Opcode.istore : -3, Opcode.opistore : -3, Opcode.opstore : -1,
        Opcode.retval : 0, Opcode.retnone : 0, Opcode.iftrue : -1,
        Opcode.iffalse : -1, Opcode.jump : 0, Opcode.argno : 1, Opcode.args : 1,
    ];

module lang.bytecode;

import lang.dynamic;
import std.stdio;

class Function
{
    struct Lookup
    {
        uint[string] byName;
        string[] byPlace;
        void clear()
        {
            byName = null;
            byPlace = null;
        }

        void set(string name, uint us)
        {
            byName[name] = us;
            byPlace ~= name;
        }

        uint define(string name)
        {
            uint ret = cast(uint)(byPlace.length);
            set(name, ret);
            return ret;
        }

        uint opIndex(string name)
        {
            return byName[name];
        }

        string opIndex(uint name)
        {
            return byPlace[name];
        }
    }

    struct Capture
    {
        uint from;
        bool is2;
    }

    enum Flags : ubyte{
        isLocal = 1,
    }

    Capture[] capture = null;
    Instr[] instrs = null;
    Dynamic[] constants = null;
    Function[] funcs = null;
    Dynamic*[] captured = null;
    size_t stackSize = 0;
    Dynamic[] self = null;

    Lookup stab;
    Lookup captab;
    Function parent = null;
    Flags flags = cast(Flags) 0;

    this()
    {
    }

    this(Function other)
    {
        capture = other.capture;
        instrs = other.instrs;
        constants = other.constants;
        funcs = other.funcs;
        parent = other.parent;
        captured = other.captured;
        stackSize = other.stackSize;
        self = other.self.dup;
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
        uint ret = captab.define(name);
        if (name in parent.stab.byName)
        {
            capture ~= Capture(parent.stab.byName[name], false);
            return ret;
        }
        else if (name in parent.captab.byName)
        {
            capture ~= Capture(parent.captab.byName[name], true);
            return ret;
        }
        else
        {
            if (parent.parent is null)
            {
                throw new Exception("name not found " ~ name);
            }
            parent.doCapture(name);
            capture ~= Capture(parent.captab.byName[name], true);
            return ret;
        }
    }

    override string toString()
    {
        return "<function>";
    }
}

enum AssignOp : uint
{
    add,
    sub,
    mul,
    div,
    mod,
}

enum Opcode
{
    // never generated
    nop,
    // stack ops
    push,
    pop,
    // change data flag
    data,
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
    // build array that will be assigned to
    targeta,
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
    store,
    istore,
    tstore,
    qstore,
    // same but with operators like += and -=
    opstore,
    opistore,
    optstore,
    opqstore,
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
}

struct Instr
{
    Opcode op;
    uint value;
}


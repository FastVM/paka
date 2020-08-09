module lang.bytecode;

import lang.dynamic;
import std.stdio;

class Function
{
    struct Lookup
    {
        ushort[string] byName;
        string[] byPlace;
        void clear()
        {
            byName = null;
            byPlace = null;
        }

        void set(string name, ushort us)
        {
            byName[name] = us;
            byPlace ~= name;
        }

        ushort define(string name)
        {
            ushort ret = cast(ushort)(byPlace.length);
            set(name, ret);
            return ret;
        }

        ushort opIndex(string name)
        {
            return byName[name];
        }

        string opIndex(ushort name)
        {
            return byPlace[name];
        }
    }

    struct Capture
    {
        ushort from;
        bool is2;
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
    bool env;

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
        env = other.env;
    }

    void useEnv()
    {
        env = true;
        if (parent !is null && !parent.env)
        {
            parent.useEnv;
        }
    }

    ushort doCapture(string name)
    {
        ushort* got = name in captab.byName;
        if (got !is null)
        {
            return *got;
        }
        ushort ret = captab.define(name);
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

enum AssignOp : ushort
{
    add,
    sub,
    mul,
    div,
    mod,
}

enum Opcode : ushort
{
    nop,
    push,
    pop,
    data,
    sub,
    bind,
    call,
    upcall,
    oplt,
    opgt,
    oplte,
    opgte,
    opeq,
    opneq,
    array,
    targeta,
    unpack,
    table,
    index,
    opneg,
    opadd,
    opsub,
    opmul,
    opdiv,
    opmod,
    load,
    loadc,
    loadenv,
    loaduse,
    use,
    store,
    istore,
    tstore,
    qstore,
    opstore,
    opistore,
    optstore,
    opqstore,
    retval,
    retnone,
    iftrue,
    iffalse,
    jump,
    douse,
    unuse,
    nonexist,
}

struct Instr
{
align(1):
    Opcode op;
    ushort value;
    ushort index;
}

module purr.bytecode;

import purr.dynamic;
import purr.srcloc;
import std.algorithm;
import std.array;
import purr.io;
import std.conv;

class Function
{
    struct Lookup
    {
        uint[string] byName;
        string[] byPlace;
        Flags[] flagsByPlace;

        enum Flags : size_t
        {
            noFlags = 0,
            noAssign = 1,
        }

        size_t length()
        {
            return byPlace.length;
        }

        void set(string name, uint us, Flags flags)
        {
            assert(byName.length == byPlace.length);
            if (name !in byName)
            {
                byName[name] = us;
                byPlace ~= name;
                flagsByPlace ~= flags;
            }
            assert(byName.length == byPlace.length, byPlace.to!string);
        }

        uint define(string name, Flags flags = Flags.noFlags)
        {
            uint ret = cast(uint)(byPlace.length);
            set(name, ret, flags);
            return ret;
        }

        Flags flags(string name)
        {
            return flagsByPlace[byName[name]];
        }

        Flags flags(T)(T index)
        {
            return flagsByPlace[index];
        }

        uint opIndex(string name)
        {
            return byName[name];
        }

        string opIndex(T)(T name)
        {
            return byPlace[name];
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
        none = 0,
        isLocal = 1,
    }

    Capture[] capture = null;
    ubyte[] instrs = null;
    Span[] spans = null;
    Dynamic[] constants = null;
    Function[] funcs = null;
    Dynamic*[] captured = null;
    Dynamic[] self = null;
    Dynamic[] args = null;
    int[size_t] stackAt = null;
    size_t stackSize = 0;
    Function parent = null;
    int stackSizeCurrent;
    Lookup stab;
    Lookup captab;
    Flags flags = Flags.none;
    Dynamic[] names;

    this()
    {
    }

    this(Function other)
    {
        copy(other);
    }

    void copy(Function other)
    {
        capture = other.capture;
        instrs = other.instrs;
        spans = other.spans;
        constants = other.constants;
        funcs = other.funcs;
        parent = other.parent;
        captured = other.captured;
        stackSize = other.stackSize;
        self = other.self;
        args = other.args.dup;
        stab = other.stab;
        captab = other.captab;
        flags = other.flags;
        stackSizeCurrent = other.stackSizeCurrent;
        stackAt = other.stackAt;
        names = other.names;
    }

    uint doCapture(string name)
    {
        uint* got = name in captab.byName;
        if (got !is null)
        {
            return *got;
        }
        foreach (argno, argname; parent.args)
        {
            if (argname == name.dynamic)
            {
                uint ret = captab.define(name);
                capture ~= Capture(cast(uint) argno, false, true);
                return ret;
            }
        }
        Lookup.Flags flags;
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
                throw new Exception(name);
            }
            parent.doCapture(name);
            capture ~= Capture(parent.captab.byName[name], true, false);
            flags = parent.captab.flags(name);
        }
        uint ret = captab.define(name, flags);
        capture[$ - 1].offset = ret;
        return ret;
    }

    override string toString()
    {
        return callableFormat(names, args);
    }
}

enum AssignOp : ubyte
{
    cat,
    add,
    sub,
    mul,
    div,
    mod,
}

enum Opcode : ushort
{
    /// never generated
    nop,
    /// stack ops
    push,
    pop,
    /// current funcion
    rec,
    /// subroutine
    sub,
    /// call without spread
    call,
    /// cmp
    oplt,
    opgt,
    oplte,
    opgte,
    opeq,
    opneq,
    /// build array
    array,
    /// built table
    table,
    /// index table or array
    index,
    /// math ops (arithmatic)
    opneg,
    opcat,
    opadd,
    opsub,
    opmul,
    opdiv,
    opmod,
    /// load from locals
    load,
    /// load from captured
    loadc,
    /// stores
    store,
    cstore,
    /// return a value
    retval,
    /// return no value
    retnone,
    /// jump if true
    iftrue,
    /// jump if false
    iffalse,
    /// jump to index
    jump,
    /// arg number
    argno,
    /// all args as list
    args,
    /// run inspect functions
    inspect,
}

/// may change: call, array, targeta, table
enum int[Opcode] opSizes = [
        Opcode.nop : 0, Opcode.push : 1, Opcode.rec : 1, Opcode.pop : -1, Opcode.sub : 1,
        Opcode.oplt : -1, Opcode.opgt : -1, Opcode.oplte : -1, Opcode.opgte
        : -1, Opcode.opeq : -1, Opcode.opneq : -1, Opcode.index : -1,
        Opcode.opneg : 0, Opcode.opcat : -1, Opcode.opadd : -1, Opcode.opsub
        : -1, Opcode.opmul : -1, Opcode.opdiv : -1, Opcode.opmod : -1,
        Opcode.load : 1, Opcode.loadc : 1,
        Opcode.retval : 0, Opcode.retnone : 0, Opcode.iftrue : -1,
        Opcode.iffalse : -1, Opcode.jump : 0, Opcode.argno : 1, Opcode.args
        : 1, Opcode.inspect : 0,
    ];

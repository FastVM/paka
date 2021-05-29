module purr.bytecode;

import purr.io;
import std.algorithm;
import std.array;
import std.conv;
import purr.dynamic;
import purr.srcloc;

final class Bytecode
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

    Capture[] capture;
    ubyte[] instrs;
    Span[] spans;
    Dynamic[] constants;
    Bytecode[] funcs;
    Dynamic*[] captured;
    Dynamic*[] cached;
    Dynamic[][] cacheCheck;
    Dynamic[] self;
    string[] args;
    int[size_t] stackAt;
    size_t stackSize = 0;
    Bytecode parent;
    int stackSizeCurrent = 1;
    Lookup stab;
    Lookup captab;
    Flags flags = Flags.none;

    this()
    {
    }

    this(Bytecode other)
    {
        copy(other);
    }

    void copy(Bytecode other)
    {
        capture = other.capture;
        instrs = other.instrs;
        spans = other.spans;
        constants = other.constants;
        funcs = other.funcs;
        parent = other.parent;
        captured = other.captured;
        cached = other.cached;
        cacheCheck = other.cacheCheck;
        stackSize = other.stackSize;
        self = other.self;
        args = other.args.dup;
        stab = other.stab;
        captab = other.captab;
        flags = other.flags;
        stackSizeCurrent = other.stackSizeCurrent;
        stackAt = other.stackAt;
    }

    int doCapture(string name)
    {
        uint* got = name in captab.byName;
        if (got !is null)
        {
            return *got;
        }
        foreach (argno, argname; parent.args)
        {
            if (argname == name)
            {
                int ret = captab.define(name);
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
                return -1;
            }
            int ret = parent.doCapture(name);
            if (ret == -1)
            {
                return -1;
            }
            capture ~= Capture(parent.captab.byName[name], true, false);
            flags = parent.captab.flags(name);
        }
        int ret = captab.define(name, flags);
        capture[$ - 1].offset = ret;
        return ret;
    }

    override string toString()
    {
        return callableFormat(args);
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
    scall,
    tcall,
    /// cmp
    oplt,
    opgt,
    oplte,
    opgte,
    opeq,
    opneq,
    /// build tuple
    tuple,
    /// build array
    array,
    /// built table
    table,
    /// index table or array
    opindex,
    opindexc,
    /// if there is a constant go to and push
    gocache,
    cbranch,
    /// math ops (arithmatic)
    opneg,
    opcat,
    opadd,
    opinc,
    opsub,
    opdec,
    opmul,
    opdiv,
    opmod,
    /// load from locals
    load,
    /// load from captured
    loadcap,
    /// stores
    store,
    istore,
    cstore,
    /// return a constant
    retconst,
    /// return a value
    retval,
    /// return no value
    retnone,
    /// jump if true
    iftrue,
    // jump to if true or false
    branch,
    /// jump if false
    iffalse,
    /// jump to index
    jump,
    /// arg number
    argno,
    /// run inspect functions
    inspect,
}

/// may change: call, array, targeta, table
enum int[Opcode] opSizes = [
        Opcode.nop : 0, Opcode.push : 1, Opcode.rec : 1, Opcode.pop : -1, Opcode.sub : 1,
        Opcode.oplt : -1, Opcode.opgt : -1, Opcode.oplte : -1, Opcode.opgte
        : -1, Opcode.opeq : -1, Opcode.opneq : -1, Opcode.opindex : -1, Opcode.opindexc : 0,
        Opcode.opneg : 0, Opcode.opcat : -1, Opcode.opadd : -1, Opcode.opsub
        : -1, Opcode.opinc : 0, Opcode.opdec
        : 0, Opcode.opmul : -1, Opcode.opdiv : -1, Opcode.opmod : -1,
        Opcode.load : 1, Opcode.loadcap : 1,
        Opcode.retval : 0, Opcode.retconst : 0, Opcode.retnone : 0, Opcode.iftrue : -1,
        Opcode.iffalse : -1, Opcode.branch : -1, Opcode.cbranch : 0, Opcode.gocache : 0, Opcode.jump : 0, Opcode.argno : 1
    ];

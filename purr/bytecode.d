module purr.bytecode;

import purr.dynamic;
import purr.srcloc;
import purr.error;
import std.algorithm;
import std.array;
import purr.io;
import std.conv;

alias Function = shared FunctionStruct;

class FunctionStruct
{
    alias Lookup = shared LookupStruct;
    struct LookupStruct
    {
        uint[string] byName;
        string[] byPlace;
        Flags[] flagsByPlace;

        enum Flags : size_t
        {
            noFlags = 0,
            noAssign = 1,
        }

        size_t length() shared
        {
            return byPlace.length;
        }

        void set(string name, uint us, Flags flags) shared
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

        shared(uint) define(string name, Flags flags = Flags.noFlags) shared
        {
            shared uint ret = cast(shared uint)(byPlace.length);
            set(name, ret, flags);
            return ret;
        }

        Flags flags(string name) shared
        {
            return flagsByPlace[byName[name]];
        }

        Flags flags(T)(T index) shared
        {
            return flagsByPlace[index];
        }

        uint opIndex(string name) shared
        {
            return byName[name];
        }

        string opIndex(T)(T name) shared
        {
            return byPlace[name];
        }
    }

    alias Capture = shared CaptureStruct;
    struct CaptureStruct
    {
        uint from;
        bool is2;
        bool isArg;
        uint offset;
    }

    alias Flags = shared FlagsEnum;
    enum FlagsEnum : ubyte
    {
        none = 0,
        isLocal = 1,
    }

    Capture[] capture = null;
    ubyte[] instrs = null;
    Span[] spans = null;
    Dynamic[] constants = null;
    Function[] funcs = null;
    shared(Dynamic*[]) captured = null;
    Dynamic[] self = null;
    Dynamic[] args = null;
    int[size_t] stackAt = null;
    size_t stackSize = 0;
    Function parent = null;
    int stackSizeCurrent;
    Lookup stab;
    Lookup captab;
    Flags flags = cast(Flags) 0;
    Dynamic[] names;

    this() shared
    {
    }

    this(Function other) shared
    {
        copy(other);
    }

    void copy(Function other) shared
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

    uint doCapture(string name) shared
    {
        shared(uint)* got = name in captab.byName;
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
        if (shared(uint)* found = name in parent.stab.byName)
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
                throw new UndefinedException(name);
            }
            parent.doCapture(name);
            capture ~= Capture(parent.captab.byName[name], true, false);
            flags = parent.captab.flags(name);
        }
        uint ret = captab.define(name, flags);
        capture[$ - 1].offset = ret;
        return ret;
    }

    string toString() shared
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

enum Opcode : ubyte
{
    /// never generated
    nop,
    /// stack ops
    push,
    pop,
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
    /// store to locals
    store,
    cstore,
    istore,
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
        Opcode.nop : 0, Opcode.push : 1, Opcode.pop : -1, Opcode.sub : 1,
        Opcode.oplt : -1, Opcode.opgt : -1, Opcode.oplte
        : -1, Opcode.opgte : -1, Opcode.opeq : -1, Opcode.opneq : -1,
        Opcode.index : -1, Opcode.opneg : 0, Opcode.opcat
        : -1, Opcode.opadd : -1, Opcode.opsub : -1, Opcode.opmul : -1,
        Opcode.opdiv : -1, Opcode.opmod : -1, Opcode.load : 1, Opcode.loadc : 1,
        Opcode.store : 0, Opcode.istore : -2,
        Opcode.retval : 0, Opcode.retnone : 0,
        Opcode.iftrue : -1, Opcode.iffalse : -1, Opcode.jump : 0,
        Opcode.argno : 1, Opcode.args : 1, Opcode.inspect: 0,
    ];

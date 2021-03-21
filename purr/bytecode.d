module purr.bytecode;

import purr.dynamic;
import purr.srcloc;
import purr.error;
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

        unittest
        {
            Lookup lookup;
            foreach (k, v; ["x", "y", "z"])
            {
                assert(lookup.length == k);
                lookup.define(v, cast(Flags) k);
            }
            foreach (k, v; ["x", "y", "z"])
            {
                assert(lookup.byPlace[k] == v, "Lookup.byPlace should work");
                assert(lookup.byPlace[k] == lookup[k], "Lookup.opIndex should work byPlace");
                assert(lookup.byName[v] == k, "Lookup.byName should work");
                assert(lookup.byName[v] == lookup[v], "Lookup.opIndex should work byName");
                assert(lookup.flags(k) == cast(Flags) k);
                assert(lookup.flags(v) == cast(Flags) k);
            }
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
    Flags flags = cast(Flags) 0;
    Dynamic[] names;
    void function() jitted;

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
        self = other.self;
        args = other.args.dup;
        stab = other.stab;
        captab = other.captab;
        flags = other.flags;
        stackSizeCurrent = other.stackSizeCurrent;
        stackAt = other.stackAt;
        names = other.names;
        jitted = other.jitted;
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

    override string toString()
    {
        return callableFormat(names, args);
    }

    version (unittest)
    {
        bool isSame(Function other)
        {
            Function self = this;
            // dfmt off
            return self.capture == other.capture
                && self.instrs == other.instrs
                && self.spans == other.spans
                && self.constants == other.constants
                && self.funcs == other.funcs
                && self.parent == other.parent
                && self.captured == other.captured
                && self.stackSize == other.stackSize
                && self.self == other.self 
                && self.args == other.args
                && self.stab == other.stab
                && self.captab == other.captab
                && self.flags == other.flags
                && self.stackSizeCurrent == other.stackSizeCurrent
                && self.stackAt == other.stackAt;
            // dfmt off
        }
    }

    unittest
    {
        assert(new Function().to!string == "<function>");
    }

    unittest
    {
        import std.algorithm;
        import purr.utest;
        enum size_t count = 8;
        static assert(count < 10, "dont test that many");
        Function last = new Function;
        foreach (i; 0..count)
        {
            Function cur = new Function;
            cur.parent = last;
            foreach (j; i..count)
            {
                cur.stab.define("v"~i.to!string~"v"~j.to!string);
            }
            foreach (j; 0..i)
            {
                cur.doCapture("v"~j.to!string~"v"~i.to!string);
            }
            assert(!ok!UndefinedException(cur.doCapture("v"~i.to!string~"v"~i.to!string)), "should not be able to capture from own symbol table");
            last = cur;
        }
    }

    unittest
    {
        Function f0 = new Function;
        Function f1 = new Function;
        f1.parent = f0;
        f0.args ~= "f0a";
        f0.captab.define("f0c");
        f0.stab.define("f0l");
        f1.doCapture("f0a");
        f1.doCapture("f0c");
        f1.doCapture("f0l");
        f1.doCapture("f0l");
        assert("f0c" in f1.captab.byName);
        assert("f0l" in f1.captab.byName);
        Capture f0c = f1.capture[f1.captab.byName["f0c"]];
        assert(f0c.is2 == true);
        assert(f0c.isArg == false);
        assert(f0c.isArg == false);
        Capture f0l = f1.capture[f1.captab.byName["f0l"]];
        assert(f0l.is2 == false);
        assert(f0l.isArg == false);
        Capture f0a = f1.capture[f1.captab.byName["f0a"]];
        assert(f0a.is2 == false);
        assert(f0a.isArg == true);
    }

    unittest
    {
        Function fa = new Function;
        fa.capture.length = 3;
        fa.instrs.length = 1;
        fa.spans.length = 4;
        fa.constants.length = 1;
        fa.funcs.length = 5;
        fa.captured.length = 9;
        fa.parent = fa;
        fa.stackSize = 2;
        fa.self.length = 6;
        fa.args.length = 5;
        fa.stab = Lookup(null, new string[3], new Lookup.Flags[8]);
        fa.captab = Lookup(null, new string[9], new Lookup.Flags[7]);
        fa.flags = cast(Flags) 9;
        fa.stackSizeCurrent = 3;
        fa.stackAt[4994] = 4984;
        Function faa = new Function(fa);
        Function fab = new Function(fa);
        Function fb = new Function;
        Function fba = new Function(fb);
        assert(fa.isSame(faa), "this(Function) should shallow copy");
        assert(fa.isSame(fab), "this(Function) should shallow copy");
        assert(faa.isSame(fab), "this(Function) should shallow copy");
        assert(fb.isSame(fba), "this(Function) should shallow copy");
        assert(!fb.isSame(fa), "this(Function) should shallow copy");
        assert(!fb.isSame(faa), "this(Function) should shallow copy");
        assert(!fb.isSame(fab), "this(Function) should shallow copy");
        assert(!fba.isSame(fa), "this(Function) should shallow copy");
        assert(!fba.isSame(faa), "this(Function) should shallow copy");
        assert(!fba.isSame(fab), "this(Function) should shallow copy");
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
    /// same but with operators like += and -=
    opstore,
    opcstore,
    opistore,
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
        Opcode.store : 0, Opcode.istore : -2, Opcode.opistore : -2,
        Opcode.opstore : 0, Opcode.retval : 0, Opcode.retnone : 0,
        Opcode.iftrue : -1, Opcode.iffalse : -1, Opcode.jump : 0,
        Opcode.argno : 1, Opcode.args : 1, Opcode.inspect: 0,
    ];

module lang.lib.sys;

import lang.dynamic;
import lang.base;
import lang.lib.sysenv;
import lang.error;
import lang.ast;
import lang.parse;
import lang.walk;
import lang.vm;
import lang.inter;
import lang.bytecode;
import core.stdc.stdlib;
import core.runtime;
import std.algorithm;
import std.file;
import std.array;
import std.conv;
import std.stdio;
import std.parallelism: parallel;

Pair[] libsys()
{
    Pair[] ret = [
        Pair("leave", &libleave), Pair("args", &libargs),
        Pair("typeof", &libtypeof), Pair("import", &libimport),
        Pair("assert", &libassert),
    ];
    ret.addLib("env", libsysenv);
    return ret;
}

/// asserts value is true, with error msg
Dynamic libassert(Args args) {
    if (args[0].type == Dynamic.Type.nil || (args[0].type == Dynamic.Type.log && !args[0].log))
    {
        throw new AssertException("assert error: " ~ args[1].to!string);
    }
    return Dynamic.nil;
}

/// imports value returning what it returned
Dynamic libimport(Args args) {
    string code = cast(string) args[0].str.read;
    Dynamic retval = evalFile(code);
    return retval;
};

/// returns type of value as a string
Dynamic libtypeof(Args args)
{
    final switch (args[0].type) {
        case Dynamic.Type.nil:
            return dynamic("nil");
        case Dynamic.Type.log:
            return dynamic("logical");
        case Dynamic.Type.sml:
            return dynamic("number");
        case Dynamic.Type.big:
            return dynamic("number");
        case Dynamic.Type.str:
            return dynamic("string");
        case Dynamic.Type.arr:
            return dynamic("array");
        case Dynamic.Type.tab:
            return dynamic("table");
        case Dynamic.Type.fun:
            return dynamic("callable");
        // case Dynamic.Type.del:
        //     return dynamic("callable");
        case Dynamic.Type.pro:
            return dynamic("callable");
        case Dynamic.Type.end:
            assert(0);
        case Dynamic.Type.pac:
            assert(0);
    } 
}

/// internal map function
Dynamic syslibmap(Args args)
{
    Dynamic[] ret;
    foreach (i; 0 .. args[1].arr.length)
    {
        Dynamic[] fargs;
        foreach (j; args[1 .. $])
        {
            fargs ~= j.arr[i];
        }
        ret ~= args[0](fargs);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic syslibubothmap(Args args)
{
    Array ret;
    if (args[1].arr.length != args[2].arr.length)
    {
        throw new BoundsException("bad lengths in dotmap");
    }
    foreach (i; 0 .. args[1].arr.length)
    {
        ret ~= args[0]([args[1].arr[i], args[2].arr[i]]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic syslibulhsmap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i, args[2]]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic sysliburhsmap(Args args)
{
    Array ret;
    foreach (i; args[2].arr)
    {
        ret ~= args[0]([args[1], i]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic syslibupremap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i]);
    }
    return dynamic(ret);
}

/// exit function
Dynamic libleave(Args args)
{
    exit(0);
    assert(0);
}

/// internal args
Dynamic libargs(Args args)
{
    return dynamic(Runtime.args.map!(x => dynamic(x)).array);
}

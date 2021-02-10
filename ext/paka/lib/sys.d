module paka.lib.sys;

import purr.dynamic;
import purr.base;
import purr.error;
import purr.ast;
import purr.parse;
import purr.ir.walk;
import purr.vm;
import purr.inter;
import purr.srcloc;
import purr.bytecode;
import purr.fs.memory;
import purr.fs.har;
import purr.fs.files;
import purr.fs.disk;
import paka.lib.sysenv;
import paka.parse;
import core.stdc.stdlib;
import core.runtime;
import std.algorithm;
import std.array;
import std.conv;
import std.stdio;
import std.parallelism: parallel;

Pair[] libsys()
{
    Pair[] ret = [
        Pair("leave", &libleave), Pair("args", &libargs),
        Pair("typeof", &libtypeof), Pair("import", &libimport),
        Pair("enforce", &libassert),
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
    Location data = args[0].str.readFile;
    Dynamic val = evalFile(data);
    return val;
}

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
        case Dynamic.Type.str:
            return dynamic("string");
        case Dynamic.Type.arr:
            return dynamic("array");
        case Dynamic.Type.tab:
            return dynamic("table");
        case Dynamic.Type.fun:
            return dynamic("callable");
        case Dynamic.Type.del:
            return dynamic("callable");
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

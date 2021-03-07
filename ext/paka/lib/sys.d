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
import std.process;
import std.conv;
import purr.io;
import std.parallelism : parallel;

Pair[] libsys()
{
    Pair[] ret = [
        FunctionPair!libleave("leave"), FunctionPair!libargs("args"),
        FunctionPair!libtypeof("typeof"), FunctionPair!libimport("import"),
        FunctionPair!libassert("enforce"), FunctionPair!libeval("eval"),
        FunctionPair!libshell("shell"),
    ];
    ret.addLib("env", libsysenv);
    return ret;
}

Dynamic libshell(Args args)
{
    auto res = executeShell(args[0].str);
    return res.output.dynamic;
}

/// asserts value is true, with error msg
Dynamic libassert(Args args)
{
    if (args[0].type == Dynamic.Type.nil || (args[0].type == Dynamic.Type.log && !args[0].log))
    {
        throw new AssertException("assert error: " ~ args[1].to!string);
    }
    return Dynamic.nil;
}

/// imports value returning what it returned
Dynamic libimport(Args args)
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    Location data = args[0].str.readFile;
    Dynamic val = ctx.eval(data);
    return val;
}

/// imports value returning what it returned
Dynamic libeval(Args args)
{
    Location data = Location(1, 1, "__eval__", args[0].str);
    Dynamic val = eval(rootBases.length - 1, data);
    return val;
}

/// returns type of value as a string
Dynamic libtypeof(Args args)
{
    final switch (args[0].type)
    {
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
    case Dynamic.Type.pro:
        return dynamic("callable");
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

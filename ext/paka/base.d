module paka.base;

import core.memory;
import std.file;
import std.conv;
import std.parallelism;
import purr.io;
import purr.dynamic;
import purr.base;
import purr.inter;
import purr.srcloc;
import purr.error;
import purr.fs.disk;
import paka.lib.io;
import paka.lib.sys;
import paka.lib.str;
import paka.lib.arr;
import paka.lib.tab;
import paka.lib.math;
import paka.enforce;

/// string concatenate for format strings and unicode literals
Dynamic strconcat(Args args)
{
    string ret;
    foreach (arg; args)
    {
        if (arg.type == Dynamic.Type.str)
        {
            ret ~= arg.str;
        }
        else
        {
            ret ~= arg.to!string;
        }
    }
    return ret.dynamic;
}
/// intern
Dynamic syslibubothmap(Args args)
{
    if (args[1].arr.length != args[2].arr.length)
    {
        throw new BoundsException("bad lengths in dotmap");
    }
    Array ret = (cast(Dynamic*) GC.malloc(args[1].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[1].arr.length];
    foreach (i, v; args[1].arr)
    {
        ret[i] = args[0]([v, args[2].arr[i]]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic syslibulhsmap(Args args)
{
    Array ret = (cast(Dynamic*) GC.malloc(args[1].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[1].arr.length];
    foreach (k, i; args[1].arr)
    {
        ret[k] = args[0]([i, args[2]]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic sysliburhsmap(Args args)
{
    Array ret = (cast(Dynamic*) GC.malloc(args[2].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[2].arr.length];
    foreach (k, i; args[2].arr)
    {
        ret[k] = args[0]([i, args[2]]);
    }
    return dynamic(ret);
}

/// internal map function
Dynamic syslibupremap(Args args)
{
    Array ret = (cast(Dynamic*) GC.malloc(args[1].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[1].arr.length];
    foreach (k, i; args[1].arr)
    {
        ret[k] = args[0]([i]);
    }
    return dynamic(ret);
}

Dynamic syslibfold(Args args)
{
    Dynamic func = args[0];
    Dynamic ret = args[1];
    foreach (elem; args[2].arr)
    {
        ret = func([ret, elem]);
    }
    return ret;
}

bool domatch(Dynamic lhs, Dynamic rhs)
{
    final switch (rhs.type)
    {
    case Dynamic.Type.nil:
        return lhs == rhs;
    case Dynamic.Type.log:
        return lhs == rhs;
    case Dynamic.Type.sml:
        return lhs == rhs;
    case Dynamic.Type.str:
        return lhs == rhs;
    case Dynamic.Type.arr:
        if (lhs.arr.length != rhs.arr.length)
        {
            return false;
        }
        foreach (index; 0..lhs.arr.length)
        {
            if (domatch(lhs.arr[index], rhs.arr[index]))
            {
                return false;
            }
        }
        return true;
    case Dynamic.Type.tab:
        return domatch(lhs, rhs.tab["match".dynamic]);
    case Dynamic.Type.fun:
        return rhs([lhs]).log;
    case Dynamic.Type.pro:
        return rhs([lhs]).log;
    }
}

Dynamic pakamatch(Args args)
{
    return domatch(args[0], args[1]).dynamic;
}

Dynamic syslibrange(Args args)
{
    long start = args[0].as!long;
    long stop = args[1].as!long;
    if (start < stop)
    {
        long dist = stop - start;
        Array ret = (cast(Dynamic*) GC.malloc(dist * Dynamic.sizeof, 0, typeid(Dynamic)))[0 .. dist];
        foreach (k, ref v; ret)
        {
            v = dynamic(k + start);
        }
        return dynamic(ret);
    }
    else if (start > stop)
    {
        long dist = start - stop;
        Array ret = (cast(Dynamic*) GC.malloc(dist * Dynamic.sizeof, 0, typeid(Dynamic)))[0 .. dist];
        foreach (k, ref v; ret)
        {
            v = dynamic(start - k);
        }
        return dynamic(ret);
    }
    else
    {
        Dynamic[] ret = null;
        return ret.dynamic;
    }
    // else
    // {
    //     Dynamic[] ret = new Dynamic[start-stop];
    //     while (start > stop)
    //     {
    //         ret ~= dynamic(start);
    //         start -= 1;
    //     }
    //     return dynamic(ret);
    // }
}

Dynamic[string] libs;
Dynamic pakaimport(Args args)
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    string filename;
    foreach (key, arg; args)
    {
        if (key != 0)
        {
            filename ~= "/";
        }
        filename ~= arg.str;
    }
    string basename = filename;
    if (Dynamic* ret = basename in libs)
    {
        return *ret;
    }
    if (filename.fsexists)
    {
    }
    else if (fsexists(filename ~ ".paka"))
    {
        filename ~= ".paka";
    }
    else
    {
        throw new Exception("import error: cannot locate: " ~ filename);
    }
    Location data = filename.readFile;
    Dynamic val = ctx.eval(data);
    libs[basename] = val;
    return val;
}

Pair[] pakaBaseLibs()
{
    Pair[] ret;
    ret ~= FunctionPair!syslibubothmap("_paka_map_both");
    ret ~= FunctionPair!syslibulhsmap("_paka_map_lhs");
    ret ~= FunctionPair!sysliburhsmap("_paka_map_rhs");
    ret ~= FunctionPair!syslibupremap("_paka_map_pre");
    ret ~= FunctionPair!syslibfold("_paka_fold");
    ret ~= FunctionPair!syslibrange("_paka_range");
    ret ~= FunctionPair!pakabeginassert("_paka_begin_assert");
    ret ~= FunctionPair!pakaassert("_paka_assert");
    ret ~= FunctionPair!strconcat("_paka_str_concat");
    ret ~= FunctionPair!pakamatch("_paka_match");
    ret ~= FunctionPair!pakaimport("_paka_import");
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    ret.addLib("math", libmath);
    return ret;
}

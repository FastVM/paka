module paka.base;

import std.conv;
import purr.io;
import purr.dynamic;
import purr.base;
import purr.error;
import paka.lib.io;
import paka.lib.sys;
import paka.lib.str;
import paka.lib.arr;
import paka.lib.tab;
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

string assertTrace()
{
    assert(false);
}

Pair[] pakaBaseLibs()
{
    Pair[] ret;
    ret ~= FunctionPair!syslibubothmap("_both_map");
    ret ~= FunctionPair!syslibulhsmap("_lhs_map");
    ret ~= FunctionPair!sysliburhsmap("_rhs_map");
    ret ~= FunctionPair!syslibupremap("_pre_map");
    ret ~= FunctionPair!pakabeginassert("_paka_begin_assert");
    ret ~= FunctionPair!pakaassert("_paka_assert");
    ret ~= FunctionPair!strconcat("_paka_str_concat");
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    return ret;
}

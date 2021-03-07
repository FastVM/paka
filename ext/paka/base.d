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

Dynamic domatch(Dynamic lhs, Dynamic rhs)
{
    final switch(rhs.type)
    {
    case Dynamic.Type.nil:
        return dynamic(lhs == rhs);
    case Dynamic.Type.log:
        return dynamic(lhs == rhs);
    case Dynamic.Type.sml:
        return dynamic(lhs == rhs);
    case Dynamic.Type.str:
        return dynamic(lhs == rhs);
    case Dynamic.Type.arr:
        return dynamic(lhs == rhs);
    case Dynamic.Type.tab:
        return rhs.tab["match".dynamic]([lhs]);
    case Dynamic.Type.fun:
        return rhs([lhs]);
    case Dynamic.Type.pro:
        return rhs([lhs]);
    }
}

Dynamic pakamatch(Args args)
{
    return domatch(args[0], args[1]);
}

Dynamic syslibrange(Args args)
{
    double start = args[0].as!double;
    double stop = args[1].as!double;
    if (args[0] < args[1])
    {
        Dynamic[] ret;
        while (start < stop)
        {
            ret ~= dynamic(start);
            start += 1;
        }
        return dynamic(ret);
    }
    else
    {
        Dynamic[] ret;
        while (start > stop)
        {
            ret ~= dynamic(start);
            start -= 1;
        }
        return dynamic(ret);
    }
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
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    ret.addLib("math", libmath);
    return ret;
}

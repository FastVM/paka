module lang.lib.sys;

import lang.dynamic;
import lang.base;
import lang.lib.sysenv;
import lang.error;
import core.stdc.stdlib;
import core.runtime;
import std.algorithm;
import std.array;
import std.stdio;
import std.parallelism;

Pair[] libsys()
{
    Pair[] ret = [
        Pair("leave", &libleave), Pair("args", &libargs),
        Pair("typeof", &libtypeof),
    ];
    ret.addLib("env", libsysenv);
    return ret;
}

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

Dynamic syslibulhsmap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i, args[2]]);
    }
    return dynamic(ret);
}

Dynamic sysliburhsmap(Args args)
{
    Array ret;
    foreach (i; args[2].arr)
    {
        ret ~= args[0]([args[1], i]);
    }
    return dynamic(ret);
}

Dynamic syslibupremap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i]);
    }
    return dynamic(ret);
}

private:
Dynamic libleave(Args args)
{
    exit(0);
    assert(0);
}

Dynamic libargs(Args args)
{
    return dynamic(Runtime.args.map!(x => dynamic(x)).array);
}

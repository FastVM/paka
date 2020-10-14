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
    ];
    ret.addLib("env", libsysenv);
    return ret;
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

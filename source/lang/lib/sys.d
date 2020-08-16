module lang.lib.sys;

import core.stdc.stdlib;
import lang.dynamic;
import std.stdio;
import std.parallelism;

Dynamic libleave(Args args)
{
    exit(0);
    assert(0);
}

Dynamic libmap(Args args)
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

Dynamic libubothmap(Args args)
{
    Array ret;
    if (args[1].arr.length != args[2].arr.length)
    {
        throw new Exception("bad lengths in dotmap");
    }
    foreach (i; 0 .. args[1].arr.length)
    {
        ret ~= args[0]([args[1].arr[i], args[2].arr[i]]);
    }
    return dynamic(ret);
}

Dynamic libulhsmap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i, args[2]]);
    }
    return dynamic(ret);
}

Dynamic liburhsmap(Args args)
{
    Array ret;
    foreach (i; args[2].arr)
    {
        ret ~= args[0]([args[1], i]);
    }
    return dynamic(ret);
}

Dynamic libupremap(Args args)
{
    Array ret;
    foreach (i; args[1].arr)
    {
        ret ~= args[0]([i]);
    }
    return dynamic(ret);
}

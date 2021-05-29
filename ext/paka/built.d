module ext.paka.built;

import core.memory;
import std.conv;
import purr.io;
import purr.dynamic;

Dynamic metaMapBothParallel(Args args)
{
    if (args[1].arr.length != args[2].arr.length)
    {
        throw new Exception("bad lengths in dotmap");
    }
    Array ret = (cast(Dynamic*) GC.calloc(args[1].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[1].arr.length];
    foreach (i, v; args[1].arr)
    {
        ret[i] = args[0]([v, args[2].arr[i]]);
    }
    return dynamic(ret);
}

Dynamic metaMapLhsParallel(Args args)
{
    Array ret = (cast(Dynamic*) GC.calloc(args[1].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[1].arr.length];
    foreach (k, i; args[1].arr)
    {
        ret[k] = args[0]([i, args[2]]);
    }
    return dynamic(ret);
}

Dynamic metaMapRhsParallel(Args args)
{
    Array ret = (cast(Dynamic*) GC.calloc(args[2].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[2].arr.length];
    foreach (k, i; args[2].arr)
    {
        ret[k] = args[0]([args[1], i]);
    }
    return dynamic(ret);
}

Dynamic metaMapPreParallel(Args args)
{
    Array ret = (cast(Dynamic*) GC.calloc(args[1].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[1].arr.length];
    foreach (k, i; args[1].arr)
    {
        ret[k] = args[0]([i]);
    }
    return dynamic(ret);
}

Dynamic metaFoldBinary(Args args)
{
    Dynamic func = args[0];
    Dynamic ret = args[1];
    foreach (elem; args[2].arr)
    {
        ret = func([ret, elem]);
    }
    return ret;
}

Dynamic metaFoldUnary(Args args)
{
    Dynamic func = args[0];
    Dynamic ret = args[1].arr[0];
    foreach (elem; args[1].arr[1 .. $])
    {
        ret = func([ret, elem]);
    }
    return ret;
}

Dynamic toOp(Args args)
{
    long start = args[0].as!long;
    long stop = args[1].as!long;
    if (start < stop)
    {
        long dist = stop - start;
        Array ret = (cast(Dynamic*) GC.calloc(dist * Dynamic.sizeof, 0, typeid(Dynamic)))[0 .. dist];
        foreach (k, ref v; ret)
        {
            v = dynamic(k + start);
        }
        return dynamic(ret);
    }
    else if (start > stop)
    {
        long dist = start - stop;
        Array ret = (cast(Dynamic*) GC.calloc(dist * Dynamic.sizeof, 0, typeid(Dynamic)))[0 .. dist];
        foreach (k, ref v; ret)
        {
            v = dynamic(start - k);
        }
        return dynamic(ret);
    }
    else
    {
        Array ret = null;
        return ret.dynamic;
    }
}

Dynamic thruOp(Args args)
{
    long start = args[0].as!long;
    long stop = args[1].as!long;
    if (start < stop)
    {
        long dist = stop - start + 1;
        Array ret = (cast(Dynamic*) GC.calloc(dist * Dynamic.sizeof, 0, typeid(Dynamic)))[0 .. dist];
        foreach (k, ref v; ret)
        {
            v = dynamic(k + start);
        }
        return dynamic(ret);
    }
    else if (start > stop)
    {
        long dist = start - stop + 1;
        Array ret = (cast(Dynamic*) GC.calloc(dist * Dynamic.sizeof, 0, typeid(Dynamic)))[0 .. dist];
        foreach (k, ref v; ret)
        {
            v = dynamic(start - k);
        }
        return dynamic(ret);
    }
    else
    {
        Array ret = null;
        return ret.dynamic;
    }
}

Dynamic strConcat(Args args)
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

Dynamic lengthOp(Args args)
{
    return args[0].arr.length.dynamic;
}

Dynamic newEmptyTable(Args args)
{
    return emptyMapping.dynamic;
}

module ext.core.lib.arr;

import core.memory;
import std.array;
import std.algorithm;
import std.parallelism;
import std.concurrency;
import std.conv;
import std.conv;
import std.random;
import purr.base;
import purr.dynamic;
import purr.io;

Pair[] libarr()
{
    Pair[] ret;
    ret ~= FunctionPair!libsplit("split");
    ret ~= FunctionPair!libfsplit("fsplit");
    ret ~= FunctionPair!libslice("slice");
    ret ~= FunctionPair!libfilter("filter");
    ret ~= FunctionPair!librange("range");
    ret ~= FunctionPair!libsorted("sorted");
    ret ~= FunctionPair!liblen("len");
    ret ~= FunctionPair!libmap("map");
    ret ~= FunctionPair!libzip("zip");
    ret ~= FunctionPair!libfrom("from");
    ret ~= FunctionPair!libshuffle("shuffle");
    ret ~= FunctionPair!libcontains("contains");
    return ret;
} /// returns a list

Dynamic libcontains(Args args)
{
    foreach (val; args[0].arr)
    {
        if (val == args[1])
        {
            return true.dynamic;
        }
    }
    return false.dynamic;
}

Dynamic libshuffle(Dynamic[] args)
{
    auto rnd = MinstdRand0(1);
    Array arr = args[0].arr.dup;
    arr.randomShuffle(rnd);
    return arr.dynamic;
}

Dynamic libfrom(Args args)
{
    return args[0].tab["arr".dynamic](args);
}

/// with one arg it returns 0..$0
/// with two args it returns $0..$1
/// with three args it counts from $0 to $1 with interval $2
Dynamic librange(Args args)
{
    if (args.length == 1)
    {
        Array ret;
        foreach (i; cast(double) 0 .. args[0].as!double)
        {
            ret ~= dynamic(i);
        }
        return dynamic(ret);
    }
    if (args.length == 2)
    {
        Array ret;
        foreach (i; args[0].as!double .. args[1].as!double)
        {
            ret ~= dynamic(i);
        }
        return dynamic(ret);
    }
    if (args.length == 3)
    {
        double start = args[0].as!double;
        double stop = args[1].as!double;
        double step = args[2].as!double;
        Array ret;
        while (start < stop)
        {
            ret ~= dynamic(start);
            start += step;
        }
        return dynamic(ret);
    }
    throw new Exception("bad number of arguments to range");
}

/// returns an array where the function has been called on each element
Dynamic libmap(Args args)
{
    Array res = (cast(Dynamic*) GC.calloc(args[0].arr.length * Dynamic.sizeof, 0, typeid(Dynamic)))[0
        .. args[0].arr.length];
    foreach (k, i; args[0].arr.parallel)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur, k.dynamic]);
        }
        res[k] = cur;
    }
    return dynamic(res);
}

/// creates new array with only the elemtns that $1 returnd true with
Dynamic libfilter(Args args)
{
    Array res;
    foreach (k, i; args[0].arr)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur, k.dynamic]);
        }
        if (cur.isTruthy)
        {
            res ~= i;
        }
    }
    return dynamic(res);
}

/// zips arrays interleaving
Dynamic libzip(Args args)
{
    Array res;
    foreach (i; 0 .. args[0].arr.length)
    {
        Array sub = new Dynamic[args.length];
        foreach (k, ref v; sub)
        {
            v = args[k].arr[i];
        }
        res ~= dynamic(sub);
    }
    return dynamic(res);
}

/// length of array
Dynamic liblen(Args args)
{
    return dynamic(args[0].arr.length);
}

/// splits array with deep equality by elemtns
Dynamic libsplit(Args args)
{
    return dynamic(args[0].arr.splitter(args[1 .. $]).map!(x => dynamic(x)).array);
}

/// splits array when function returns true
Dynamic libfsplit(Args args)
{
    Array ret;
    Array last;
    Array input = args[0].arr;
    size_t index = 0;
    while (index < input.length)
    {
        Dynamic cur = args[1](input[index .. $]);
        if (cur.isTruthy)
        {
            last ~= input[index];
            index++;
        }
        else if (cur.isNumber)
        {
            ret ~= last.dynamic;
            last = null;
            index += cur.as!size_t;
        }
        else
        {
            ret ~= last.dynamic;
            last = null;
            index += 1;
        }
    }
    ret ~= last.dynamic;
    return ret.dynamic;
}

/// slices array from 0..$1 for 1 argumnet
/// slices array from $1..$2 for 2 argumnets
Dynamic libslice(Args args)
{
    if (args.length == 3)
    {
        return dynamic(args[0].arr[args[1].as!size_t .. args[2].as!size_t].dup);
    }
    else if (args.length == 2)
    {
        return dynamic(args[0].arr[0..$-args[1].as!size_t].dup);
    }
    else
    {
        throw new Exception("arr.slice takes 3 arguments");
    }
}

Dynamic libsorted(Args args)
{
    if (args.length == 1)
    {
        return args[0].arr.sort.array.dynamic;
    }
    else
    {
        throw new Exception("bad number of arguments to sort");
    }
}

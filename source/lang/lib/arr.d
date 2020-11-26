module lang.lib.arr;
import lang.base;
import lang.dynamic;
import lang.number;
import lang.error;
import std.array;
import std.algorithm;
import std.stdio;
import std.conv;
import core.atomic;

Pair[] libarr()
{
    Pair[] ret = [
        Pair("len", &liblen), Pair("split", &libsplit), Pair("push",
                &libpush), Pair("extend", dynamic(&libextend)),
        Pair("pop", &libpop), Pair("slice", &libslice), Pair("zip",
                &libzip), Pair("range", &librange), Pair("map", &libmap),
        Pair("each", &libeach), Pair("filter", &libfilter),
    ];
    return ret;
}

/// returns a list
/// with one arg it returns 0..$0
/// with two args it returns $1..$1
/// with three args it counts from $0 to $1 with interval $2
void librange(Cont cont, Args args)
{
    if (args.length == 1)
    {
        Array ret;
        foreach (i; cast(double) 0 .. args[0].as!double)
        {
            ret ~= dynamic(i);
        }
        cont(dynamic(ret));
        return;
    }
    if (args.length == 2)
    {
        Array ret;
        foreach (i; args[0].as!double .. args[1].as!double)
        {
            ret ~= dynamic(i);
        }
        cont(dynamic(ret));
        return;
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
        cont(dynamic(ret));
        return;
    }
    throw new TypeException("bad number of arguments to range");
}

/// returns an array where the function has been called on each element
void libmap(Cont cont, Args args)
{
    shared size_t count = args[0].arr.length;
    Array res = new Dynamic[count];
    Cont subcont(size_t n)
    {
        return (Dynamic d) {
            core.atomic.atomicOp!"-="(count, 1);
            res[n] = d;
            if (count == 0)
            {
                cont(dynamic(res));
                return;
            }
        };
    }

    if (count == 0)
    {
        cont(dynamic(cast(Array)[]));
        return;
    }
    foreach (i, cur; args[0].arr)
    {
        args[1](subcont(i), [cur]);
    }
}

/// calls args[1] on each args[0] and returns nil
void libeach(Cont cont, Args args)
{
    shared size_t count = args[0].arr.length;
    Cont subcont(size_t n)
    {
        return (Dynamic d) {
            core.atomic.atomicOp!"-="(count, 1);
            if (count == 0)
            {
                cont(Dynamic.nil);
                return;
            }
        };
    }

    if (count == 0)
    {
        cont(Dynamic.nil);
        return;
    }
    foreach (i, cur; args[0].arr)
    {
        args[1](subcont(i), [cur]);
    }
}


/// creates new array with only the elemtns that $1 returnd true with
void libfilter(Cont cont, Args args)
{
    Array res;
    size_t count = args[0].arr.length;
    void delegate(Dynamic) subcont(Dynamic from)
    {
        return (Dynamic got) {
            count--;
            if (got.isTruthy)
            {
                res ~= from;
            }
            if (count == 0)
            {
                cont(dynamic(res));
                return;
            }
        };
    }

    if (count == 0)
    {
        cont(dynamic(cast(Array)[]));
        return;
    }
    foreach (cur; args[0].arr)
    {
        args[1](subcont(cur), [cur]);
    }
}

/// zips arrays interleaving
void libzip(Cont cont, Args args)
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
    cont(dynamic(res));
    return;
}

/// length of array
void liblen(Cont cont, Args args)
{
    cont(dynamic(args[0].arr.length));
    return;
}

/// splits array with deep equality by elemtns
void libsplit(Cont cont, Args args)
{
    cont(dynamic(args[0].arr.splitter(args[1]).map!(x => dynamic(x)).array));
    return;
}

/// pushes to an existing array, returning nil
void libpush(Cont cont, Args args)
{
    *args[0].arrPtr ~= args[1 .. $];
    cont(Dynamic.nil);
    return;
}

/// pops from an existing array, returning nil
void libpop(Cont cont, Args args)
{
    (*args[0].arrPtr).length--;
    cont(Dynamic.nil);
    return;
}

/// extends pushes arrays to array
void libextend(Cont cont, Args args)
{
    foreach (i; args[1 .. $])
    {
        (*args[0].arrPtr) ~= i.arr;
    }
    cont(Dynamic.nil);
    return;
}

/// slices array from 0..$1 for 1 argumnet
/// slices array from $1..$2 for 2 argumnets
void libslice(Cont cont, Args args)
{
    if (args.length == 2)
    {
        cont(dynamic(args[0].arr[args[1].as!size_t .. $].dup));
        return;
    }
    else
    {
        cont(dynamic(args[0].arr[args[1].as!size_t .. args[2].as!size_t].dup));
        return;
    }
}

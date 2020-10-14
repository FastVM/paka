module lang.lib.arr;
import lang.base;
import lang.dynamic;
import lang.number;
import lang.error;
import std.array;
import std.algorithm;
import std.stdio;
import std.conv;

Pair[] libarr()
{
    Pair[] ret = [
        Pair("len", &liblen), Pair("split", &libsplit),
        Pair("push", &libpush), Pair("extend",
                dynamic(&libextend)), Pair("pop", &libpop),
        Pair("slice", &libslice), Pair("map", &libmap),
        Pair("filter", &libfilter), Pair("zip", &libzip),
        Pair("range", &librange), Pair("each", &libmap),
    ];
    return ret;
}

private:
Dynamic librange(Args args)
{
    if (args.length == 1)
    {
        Dynamic[] ret;
        foreach (i; cast(double) 0 .. args[0].as!double)
        {
            ret ~= dynamic(i);
        }
        return dynamic(ret);
    }
    if (args.length == 2)
    {
        Dynamic[] ret;
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
        Dynamic[] ret;
        while (start < stop)
        {
            ret ~= dynamic(start);
            start += step;
        }
        return dynamic(ret);
    }
    throw new TypeException("bad number of arguments to range");
}

Dynamic libmap(Args args)
{
    Dynamic[] res;
    foreach (i; args[0].arr)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur]);
        }
        res ~= cur;
    }
    return dynamic(res);
}

Dynamic libeach(Args args)
{
    foreach (i; args[0].arr)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur]);
        }
    }
    return Dynamic.nil;
}

Dynamic libfilter(Args args)
{
    Dynamic[] res;
    foreach (i; args[0].arr)
    {
        Dynamic cur = i;
        foreach (f; args[1 .. $])
        {
            cur = f([cur]);
        }
        if (cur.type != Dynamic.Type.nil && (cur.type != Dynamic.Type.log || cur.log))
        {
            res ~= i;
        }
    }
    return dynamic(res);
}

Dynamic libzip(Args args)
{
    Dynamic[] res;
    foreach (i; 0 .. args[0].arr.length)
    {
        Dynamic[] sub = new Dynamic[args.length];
        foreach (k, ref v; sub)
        {
            v = args[k].arr[i];
        }
        res ~= dynamic(sub);
    }
    return dynamic(res);
}

Dynamic liblen(Args args)
{
    return dynamic(args[0].arr.length);
}

Dynamic libsplit(Args args)
{
    return dynamic(args[0].arr.splitter(args[1]).map!(x => dynamic(x)).array);
}

Dynamic libpush(Args args)
{
    *args[0].arrPtr ~= args[1 .. $];
    return Dynamic.nil;
}

Dynamic libpop(Args args)
{
    (*args[0].arrPtr).length--;
    return Dynamic.nil;
}

Dynamic libextend(Args args)
{
    foreach (i; args[1 .. $])
    {
        (*args[0].arrPtr) ~= i.arr;
    }
    return Dynamic.nil;
}

Dynamic libslice(Args args)
{
    if (args.length == 2)
    {
        return dynamic(args[0].arr[args[1].as!size_t .. $]);
    }
    else
    {
        return dynamic(args[0].arr[args[1].as!size_t .. args[2].as!size_t]);
    }
}

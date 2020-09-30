module lang.lib.arr;
import lang.base;
import lang.dynamic;
import lang.number;
import std.array;
import std.algorithm;
import std.stdio;
import std.conv;

Pair[] libarr()
{
    Pair[] ret = [
        Pair("len", dynamic(&liblen)), Pair("split", dynamic(&libsplit)),
        Pair("push", dynamic(&libpush)), Pair("extend",
                dynamic(&libextend)), Pair("pop", dynamic(&libpop)),
        Pair("slice", dynamic(&libslice)),
    ];
    return ret;
}

private:
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


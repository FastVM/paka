module lang.lib.str;

import lang.base;
import lang.dynamic;
import std.array;
import std.algorithm;
import std.stdio;
import std.conv;
import std.uni;

Pair[] libstr()
{
    Pair[] ret = [
        Pair("len", dynamic(&liblen)), Pair("split", dynamic(&libsplit)),
        Pair("join", dynamic(&libjoin)), Pair("chars", dynamic(&libchars)),
        Pair("subs", dynamic(&libsubs)), Pair("to_upper",
                dynamic(&libtoupper)), Pair("to_lower", dynamic(&libtolower)),
        Pair("to_number", dynamic(&libtonumber)),
        Pair("slice", dynamic(&libslice)),
    ];
    return ret;
}

private:
Dynamic liblen(Args args)
{
    return dynamic(args[0].str.length);
}

Dynamic libsplit(Args args)
{
    return dynamic(args[0].str.splitter(args[1].str).map!(x => dynamic(x)).array);
}

Dynamic libjoin(Args args)
{
    return dynamic(cast(string) args[1].arr.arr.map!(x => x.str).joiner(args[0].str).array);
}

Dynamic libchars(Args args)
{
    return dynamic(args[0].str.map!(x => dynamic(x.to!string)).array);
}

Dynamic libsubs(Args args)
{
    return dynamic(cast(string) args[0].str.substitute(args[1].str, args[2].str).array);
}

Dynamic libtoupper(Args args)
{
    return dynamic(args[0].str.toUpper);
}

Dynamic libtolower(Args args)
{
    return dynamic(args[0].str.toLower);
}

Dynamic libtonumber(Args args)
{
    return dynamic(args[0].str.to!double);
}

Dynamic libslice(Args args)
{
    if (args.length == 2)
    {
        return dynamic(args[0].str[cast(size_t) args[1].num .. $]);
    }
    else
    {
        return dynamic(args[0].str[cast(size_t) args[1].num .. cast(size_t) args[2].num]);
    }
}

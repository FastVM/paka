module lang.lib.str;

import lang.base;
import lang.dynamic;
import std.array;
import std.algorithm;
import std.stdio;
import std.conv;

Pair[] libstr()
{
    Pair[] ret = [
        Pair("len", dynamic(&liblen)), Pair("split", dynamic(&libsplit)),
        Pair("join", dynamic(&libjoin)), Pair("chars", dynamic(&libchars)),
        Pair("subs", dynamic(&libsubs)),
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
    return dynamic(cast(string) args[1].arr.map!(x => x.str).joiner(args[0].str).array);
}

Dynamic libchars(Args args)
{
    return dynamic(args[0].str.map!(x => dynamic(x.to!string)).array);
}

Dynamic libsubs(Args args)
{
    return dynamic(cast(string) args[0].str.substitute(args[1].str, args[2].str).array);
}

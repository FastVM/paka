module lang.lib.str;

import lang.base;
import lang.dynamic;
import lang.number;
import std.array;
import std.string;
import std.algorithm;
import std.stdio;
import std.conv;
import std.uni;

Pair[] libstr()
{
    Pair[] ret = [
        Pair("len", &liblen), Pair("split", &libsplit),
        Pair("join", &libjoin), Pair("chars", &libchars),
        Pair("subs", &libsubs), Pair("to_upper",
                dynamic(&libtoupper)), Pair("to_lower", &libtolower),
        Pair("to_number", &libtonumber),
        Pair("slice", &libslice), Pair("strip",
                dynamic(&libstrip)), Pair("char", &libchar),
        Pair("ascii", &libascii),
    ];
    return ret;
}

private:
Dynamic liblen(Args args)
{
    return dynamic(args[0].str.length);
}

Dynamic libascii(Args args)
{
    return dynamic(cast(double) args[0].str[0]);
}

Dynamic libchar(Args args)
{
    return dynamic(cast(string) [cast(char) args[0].as!size_t]);
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
    return Dynamic.strToNum(args[0].str);
}

Dynamic libstrip(Args args)
{
    return dynamic(args[0].str.strip);
}

Dynamic libslice(Args args)
{
    if (args.length == 2)
    {
        return dynamic(args[0].str[args[1].as!size_t .. $]);
    }
    else
    {
        return dynamic(args[0].str[args[1].as!size_t .. args[2].as!size_t]);
    }
}

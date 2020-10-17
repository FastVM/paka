module lang.lib.tab;
import lang.base;
import lang.dynamic;
import std.stdio;

Pair[] libtab()
{
    Pair[] ret = [];
    ret.addLib("meta", libmeta);
    ret.addLib("raw", libraw);
    return ret;
}

Pair[] libmeta()
{
    Pair[] ret = [
        Pair("get", &libmetaget),
        Pair("set", &libmetaset),
    ];
    return ret;
}

Pair[] libraw()
{
    Pair[] ret = [
        Pair("get", &librawset),
        Pair("set", &librawget),
    ];
    return ret;
}

Dynamic libmetaset(Dynamic[] args)
{
    args[0].tab.meta = args[1].tab;
    return args[0];
}

Dynamic libmetaget(Dynamic[] args)
{
    return dynamic(args[0].tab.meta);
}

Dynamic librawget(Dynamic[] args)
{
    return dynamic(args[0].tab.table[args[1]]);
}

Dynamic librawset(Dynamic[] args)
{
    args[0].tab.table[args[1]] = args[2];
    return Dynamic.nil;
}
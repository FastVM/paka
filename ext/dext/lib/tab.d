module dext.lib.tab;
import purr.base;
import purr.dynamic;
import purr.data.map;
import std.stdio;

Pair[] libtab()
{
    Pair[] ret = [
        Pair("map_arr", &libmaparr), Pair("map", &libmap),
        Pair("each", &libeach), Pair("filter", &libfilter),
        Pair("filter_keys", &libfilterkeys),
        Pair("filter_values", &libfiltervalues),
        Pair("len", &liblen),
    ];
    ret.addLib("meta", libmeta);
    ret.addLib("raw", libraw);
    return ret;
}

Pair[] libmeta()
{
    Pair[] ret = [Pair("get", &libmetaget), Pair("set", &libmetaset),];
    return ret;
}

Pair[] libraw()
{
    Pair[] ret = [Pair("get", &librawset), Pair("set", &librawget),];
    return ret;
}

Dynamic libmap(Args args)
{
    Mapping ret = emptyMapping;
    foreach (key, value; args[0].tab)
    {
        ret[key] = args[1]([key, value]);
    }
    Table tab = new Table(ret, args[0].tab.meta);
    return dynamic(tab);
}

Dynamic libmaparr(Args args)
{
    Dynamic[] ret;
    foreach (key, value; args[0].tab)
    {
        ret ~= args[1]([key, value]);
    }
    return dynamic(ret);
}

Dynamic libeach(Args args)
{
    foreach (key, value; args[0].tab)
    {
        args[1]([key, value]);
    }
    return Dynamic.init;
}

Dynamic libfiltervalues(Args args)
{
    Dynamic[] ret;
    foreach (key, value; args[0].tab)
    {
        if (args[1]([key, value]).isTruthy)
        {
            ret ~= value;
        }
    }
    return dynamic(ret);
}

Dynamic libfilterkeys(Args args)
{
    Dynamic[] ret;
    foreach (key, value; args[0].tab)
    {
        if (args[1]([key, value]).isTruthy)
        {
            ret ~= key;
        }
    }
    return dynamic(ret);
}

Dynamic libfilter(Args args)
{
    Mapping ret = emptyMapping;
    foreach (key, value; args[0].tab)
    {
        if (args[1]([key, value]).isTruthy)
        {
            ret[key] =  value;
        }
    }
    Table tab = new Table(ret, args[0].tab.meta);
    return dynamic(tab);
}

Dynamic libmetaset(Args args)
{
    args[0].tab.meta = args[1].tab;
    return args[0];
}

Dynamic libmetaget(Args args)
{
    return dynamic(args[0].tab.meta);
}

Dynamic librawget(Args args)
{
    return dynamic(args[0].tab.rawIndex(args[1]));
}

Dynamic librawset(Args args)
{
    args[0].tab.table[args[1]] = args[2];
    return Dynamic.nil;
}

Dynamic liblen(Args args)
{
    return dynamic(args[0].tab.length);
}

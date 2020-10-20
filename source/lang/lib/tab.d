module lang.lib.tab;
import lang.base;
import lang.dynamic;
import lang.data.map;
import std.stdio;

Pair[] libtab()
{
    Pair[] ret = [
        Pair("map_arr", &libmaparr), Pair("map", &libmap),
        Pair("each", &libeach), Pair("filter", &libfilter),
        Pair("filter_keys", &libfilterkeys),
        Pair("filter_keys", &libfiltervalues),
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

Dynamic libmap(Dynamic[] args)
{
    Map!(Dynamic, Dynamic) ret;
    foreach (key, value; args[0].tab)
    {
        ret[key] = args[1]([key, value]);
    }
    Table tab = new Table(ret, args[0].tab.meta);
    return dynamic(tab);
}

Dynamic libmaparr(Dynamic[] args)
{
    Dynamic[] ret;
    foreach (key, value; args[0].tab)
    {
        ret ~= args[1]([key, value]);
    }
    return dynamic(ret);
}

Dynamic libeach(Dynamic[] args)
{
    foreach (key, value; args[0].tab)
    {
        args[1]([key, value]);
    }
    return Dynamic.init;
}

Dynamic libfiltervalues(Dynamic[] args)
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

Dynamic libfilterkeys(Dynamic[] args)
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

Dynamic libfilter(Dynamic[] args)
{
    Map!(Dynamic, Dynamic) ret;
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

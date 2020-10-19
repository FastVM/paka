module lang.lib.tab;
import lang.base;
import lang.dynamic;
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
    Dynamic[Dynamic] ret;
    foreach (kv; args[0].tab.byKeyValue)
    {
        ret[kv.key] = args[1]([kv.key, kv.value]);
    }
    Table tab = new Table(ret, args[0].tab.meta);
    return dynamic(tab);
}

Dynamic libmaparr(Dynamic[] args)
{
    Dynamic[] ret;
    foreach (kv; args[0].tab.byKeyValue)
    {
        ret ~= args[1]([kv.key, kv.value]);
    }
    return dynamic(ret);
}

Dynamic libeach(Dynamic[] args)
{
    foreach (kv; args[0].tab.byKeyValue)
    {
        args[1]([kv.key, kv.value]);
    }
    return Dynamic.init;
}

Dynamic libfiltervalues(Dynamic[] args)
{
    Dynamic[] ret;
    foreach (kv; args[0].tab.byKeyValue)
    {
        if (args[1]([kv.key, kv.value]).isTruthy)
        {
            ret ~= kv.value;
        }
    }
    return dynamic(ret);
}

Dynamic libfilterkeys(Dynamic[] args)
{
    Dynamic[] ret;
    foreach (kv; args[0].tab.byKeyValue)
    {
        if (args[1]([kv.key, kv.value]).isTruthy)
        {
            ret ~= kv.key;
        }
    }
    return dynamic(ret);
}

Dynamic libfilter(Dynamic[] args)
{
    Dynamic[Dynamic] ret;
    foreach (kv; args[0].tab.byKeyValue)
    {
        if (args[1]([kv.key, kv.value]).isTruthy)
        {
            ret[kv.key] =  kv.value;
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

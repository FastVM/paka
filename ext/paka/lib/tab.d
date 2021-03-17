module paka.lib.tab;
import purr.base;
import purr.dynamic;
import purr.io;

Pair[] libtab()
{
    Pair[] ret = [
        FunctionPair!libmaparr("map_arr"), FunctionPair!libmap("map"),
        FunctionPair!libeach("each"), FunctionPair!libfilter("filter"),
        FunctionPair!libfilterkeys("filter_keys"),
        FunctionPair!libfiltervalues("filter_values"),
        FunctionPair!liblen("len"), 
    ];
    ret.addLib("meta", libmeta);
    ret.addLib("raw", libraw);
    return ret;
}

Pair[] libmeta()
{
    Pair[] ret = [FunctionPair!libmetaget("get"), FunctionPair!libmetaset("set"),];
    return ret;
}

Pair[] libraw()
{
    Pair[] ret = [FunctionPair!librawset("get"), FunctionPair!librawget("set"),];
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

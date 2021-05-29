module ext.core.lib.tab;
import purr.base;
import purr.dynamic;
import purr.io;

Pair[] libtab()
{
    Pair[] ret = [
        FunctionPair!libmaparr("map_arr"), FunctionPair!libmap("map"),
        FunctionPair!libeach("foreach"), FunctionPair!libfilter("filter"),
        FunctionPair!libfilterkeys("filter_keys"),
        FunctionPair!libfiltervalues("filter_values"),
        FunctionPair!liblen("len"), 
    ];
    return ret;
}

Dynamic libmap(Args args)
{
    Mapping ret = emptyMapping;
    foreach (key, value; args[0].tab)
    {
        ret[key] = args[1]([key, value]);
    }
    Table tab = new Table(ret);
    return dynamic(tab);
}

Dynamic libmaparr(Args args)
{
    Array ret;
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
    Array ret;
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
    Array ret;
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
    Table tab = new Table(ret);
    return dynamic(tab);
}

Dynamic liblen(Args args)
{
    return dynamic(args[0].tab.length);
}

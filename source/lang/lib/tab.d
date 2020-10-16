module lang.lib.tab;
import lang.base;
import lang.dynamic;

Pair[] libtab()
{
    Pair[] ret = [
    ];
    ret.addLib("meta", libmeta);
    return ret;
}

private:
Pair[] libmeta()
{
    Pair[] ret = [
        Pair("get", &libmetaget),
        Pair("set", &libmetaset),
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
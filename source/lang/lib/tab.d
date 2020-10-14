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
        Pair("of", &libmetaof),
    ];
    return ret;
}

Dynamic libmetaof(Dynamic[] args)
{
    return dynamic(args[0].tab.meta);
}
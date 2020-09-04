module lang.lib.repl;

import lang.base;
import lang.dynamic;

Pair[] librepl()
{
    Pair[] ret = [];
    ret.addLib("config", libconfig);
    return ret;
}

private:
Pair[] libconfig()
{
    Pair[] ret = [
        Pair("hints", dynamic(2 ^^ 12)), Pair("instrs", dynamic(2 ^^ 24)),
    ];
    return ret;
}

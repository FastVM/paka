module paka.base;

import purr.base;
import paka.lib.io;
import paka.lib.sys;
import paka.lib.str;
import paka.lib.arr;
import paka.lib.tab;

Pair[] dextBaseLibs()
{
    Pair[] ret;
    ret ~= Pair("_both_map", &syslibubothmap);
    ret ~= Pair("_lhs_map", &syslibulhsmap);
    ret ~= Pair("_rhs_map", &sysliburhsmap);
    ret ~= Pair("_pre_map", &syslibupremap);
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    return ret;
}
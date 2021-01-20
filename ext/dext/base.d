module dext.base;

import purr.base;
import dext.lib.io;
import dext.lib.sys;
import dext.lib.str;
import dext.lib.arr;
import dext.lib.tab;
import dext.lib.fiber;

Pair[] dextBaseLibs()
{
    Pair[] ret;
    ret ~= Pair("_both_map", &syslibubothmap);
    ret ~= Pair("_lhs_map", &syslibulhsmap);
    ret ~= Pair("_rhs_map", &sysliburhsmap);
    ret ~= Pair("_pre_map", &syslibupremap);
    ret.addLib("fiber", libfiber);
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    return ret;
}
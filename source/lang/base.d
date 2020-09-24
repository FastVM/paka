module lang.base;

import std.algorithm;
import lang.dynamic;
import lang.bytecode;
import lang.lib.io;
import lang.lib.sys;
import lang.lib.str;
import lang.lib.arr;
import lang.lib.ctfe;

Pair[] rootCtfeBase()
{
    Dynamic dynamic(Dynamic function(Args args) fn)
    {
        return dynamic(fn);
    }

    return [
        Pair("print", dynamic(&lang.lib.ctfe.ctfelibprint)),
        Pair("read", dynamic(&lang.lib.ctfe.ctfelibread)),
        Pair("run_entry", dynamic(&lang.lib.ctfe.ctfelibentry)),
    ];
}

Dynamic*[] loadCtfeBase()
{
    Dynamic*[] ret;
    foreach (i; rootCtfeBase)
    {
        ret ~= [i.val].ptr;
    }
    return ret;
}

Function baseCtfeFunction()
{
    Function ret = new Function;
    uint[string] byName;
    foreach (i; rootCtfeBase)
    {
        byName[i.name] = cast(uint) byName.length;
    }
    string[] byPlace = ["print"];
    ret.stab = Function.Lookup(byName, byPlace);
    return ret;
}

struct Pair
{
    string name;
    Dynamic val;
}

Pair[][] rootBases;

ref Pair[] rootBase(size_t index = rootBases.length - 1)
{
    return rootBases[index];
}

static this()
{
    rootBases ~= getRootBase;
}

size_t enterCtx()
{
    rootBases ~= getRootBase;
    return rootBases.length - 1;
}

void exitCtx()
{
    rootBases.length--;
}

void defineRoot(string name, Dynamic val)
{
    rootBase ~= Pair(name, val);
}

void addLib(ref Pair[] pairs, string name, Pair[] lib)
{
    foreach (entry; lib)
    {
        pairs ~= Pair(name ~ "." ~ entry.name, entry.val);
    }
    Table dyn;
    foreach (entry; lib)
    {
        if (!entry.name.canFind('.'))
        {
            dyn[dynamic(entry.name)] = entry.val;
        }
    }
    pairs ~= Pair(name, dynamic(dyn));
}

Pair[] getRootBase()
{
    Pair[] ret = [
        Pair("_both_map", dynamic(&libubothmap)),
        Pair("_lhs_map", dynamic(&libulhsmap)),
        Pair("_rhs_map", dynamic(&liburhsmap)),
        Pair("_pre_map", dynamic(&libupremap)),
    ];
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    // ret.addLib("func", librepl);
    return ret;
}

Function baseFunction(size_t ctx = rootBases.length - 1)
{
    Function ret = new Function;
    uint[string] byName;
    foreach (i; ctx.rootBase)
    {
        byName[i.name] = cast(uint) byName.length;
    }
    string[] byPlace = ["print"];
    ret.stab = Function.Lookup(byName, byPlace);
    return ret;
}

Dynamic*[] loadBase(size_t ctx = rootBases.length - 1)
{
    Dynamic*[] ret;
    foreach (i; ctx.rootBase)
    {
        ret ~= [i.val].ptr;
    }
    return ret;
}

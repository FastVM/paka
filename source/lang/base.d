module lang.base;

import std.algorithm;
import std.stdio;
import lang.dynamic;
import lang.bytecode;
import lang.data.map;
import lang.lib.io;
import lang.lib.sys;
import lang.lib.str;
import lang.lib.arr;
import lang.lib.tab;
import lang.lib.proc;
import lang.lib.fiber;

struct Pair
{
    string name;
    Dynamic val;
    this(T...)(string n, T v)
    {
        name = n;
        val = dynamic(v);
    }
}

Pair[][] rootBases;

ref Pair[] rootBase(size_t index = rootBases.length - 1)
{
    return rootBases[index];
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
    Mapping dyn = emptyMapping;
    foreach (entry; lib)
    {
        if (!entry.name.canFind('.'))
        {
            dyn[dynamic(entry.name)] = entry.val;
        }
    }
    pairs ~= Pair(name, dyn);
}

Pair[] getRootBase()
{
    Pair[] ret = [
        Pair("_both_map", &syslibubothmap),
        Pair("_lhs_map", &syslibulhsmap),
        Pair("_rhs_map", &sysliburhsmap),
        Pair("_pre_map", &syslibupremap),
    ];
    ret.addLib("fiber", libfiber);
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    ret.addLib("proc", libproc);
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

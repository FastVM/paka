module lang.base;

import lang.dynamic;
import lang.bytecode;
import lang.lib.io;
import lang.lib.serial;
import lang.lib.sys;
import lang.lib.str;
import lang.lib.arr;
import lang.lib.repl;
import std.algorithm;
import std.stdio;

bool enableIo = true;
bool ioUsed = false;

struct Pair
{
    string name;
    Dynamic val;
}

Pair[] rootBase;
Dynamic[string] rootFuncs;
string[Dynamic] serialLookup;

static this()
{
    rootBase = getRootBase;
    serialLookup = baseLookup;
    rootFuncs = funcLookup;
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
    Pair[] ret;
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("io", libio);
    ret.addLib("json", libjson);
    ret.addLib("sys", libsys);
    ret.addLib("repl", librepl);
    return ret;
}

Function baseFunction()
{
    Function ret = new Function;
    ushort[string] byName;
    foreach (i; rootBase)
    {
        byName[i.name] = cast(ushort) byName.length;
    }
    string[] byPlace = [];
    ret.stab = Function.Lookup(byName, byPlace);
    return ret;
}

string[Dynamic] baseLookup()
{
    string[Dynamic] ret;
    foreach (i; rootBase)
    {
        ret[i.val] = i.name;
    }
    return ret;
}

Dynamic[string] funcLookup()
{
    Dynamic[string] ret;
    foreach (i; rootBase)
    {
        ret[i.name] = i.val;
    }
    return ret;
}

Dynamic*[] loadBase()
{
    Dynamic*[] ret;
    foreach (i; rootBase)
    {
        ret ~= [i.val].ptr;
    }
    return ret;
}

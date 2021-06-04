module purr.base;

import std.algorithm;
import purr.io;
import std.conv;
import std.traits;
import purr.dynamic;
import purr.vm.bytecode;
import purr.plugin.syms;
import purr.plugin.plugins;

Pair FunctionPair(alias func)(string name)
{
    Fun fun = native!func;
    return Pair(name, fun);
}

struct Pair
{
    string name;
    Dynamic val;
    this(T)(string n, T v) 
    {
        name = n;
        val = v.dynamic;
    }
}

__gshared Pair[][] rootBases;

ref Pair[] rootBase(size_t index = rootBases.length - 1)
{
    assert(index < rootBases.length);
    return rootBases[index];
}

size_t enterCtx()
{
    rootBases ~= pluginLib;
    return rootBases.length - 1;
}

void exitCtx()
{
    rootBases.length--;
}

Mapping baseObject(size_t ctx)
{
    Mapping ret;
    foreach (pair; rootBases[ctx])
    {
        ret[pair.name.dynamic] = pair.val;
    }
    return ret;
}

void loadBaseObject(size_t ctx, Mapping map)
{
    rootBases[ctx] = null;
    foreach (key, value; map)
    {
        rootBases[ctx] ~= Pair(key.str, value);
    }
}

Table addLib(ref Pair[] pairs, string name, Pair[] lib)
{
    Mapping dyn = emptyMapping;
    foreach (entry; lib)
    {
        if (!entry.name.canFind('.'))
        {
            string newName = name ~ "." ~ entry.name;
            dyn[dynamic(entry.name)] = entry.val;
        }
    }
    Table ret = new Table(dyn);
    pairs ~= Pair(name, ret);
    return ret;
}
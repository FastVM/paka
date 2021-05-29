module purr.base;

import std.algorithm;
import purr.io;
import std.conv;
import std.traits;
import purr.dynamic;
import purr.bytecode;
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

// TODO: return Bytecode.Lookup instead of empty function
Bytecode.Lookup baseFunctionLookup(size_t ctx)
{
    Bytecode.Lookup stab = Bytecode.Lookup(null, null);
    foreach (name; ctx.rootBase)
    {
        stab.define(name.name);
    }
    return stab;
}

Dynamic*[] loadBase(size_t ctx)
{
    Dynamic*[] ret;
    foreach (i; ctx.rootBase)
    {
        ret ~= new Dynamic(i.val);
    }
    return ret;
}

Bytecode baseFunction(size_t ctx = rootBases.length-1)
{
    Bytecode func = new Bytecode;
    func.stab = ctx.baseFunctionLookup;
    func.captured = ctx.loadBase;
    return func;
}

version(unittest)
{
    enum string[] libnames = ["varunit", "unttest", "_unit_test", "_purr.unittest.lib", "", "123", "\x04\x09\x08\x04", "\"\""];
    enum string[] varnames = ["i have spaces", "\0", "()", "nil", ".", "args", "if"];
    enum string voidname = "void";

    Dynamic libunitvoid(Args args)
    {
        return args.dynamic;
    }

    Pair[] libunit()
    {
        return [
            FunctionPair!libunitvoid("void"),
            Pair("value", 10),
        ];
    }
}
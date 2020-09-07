module lang.base;

import lang.dynamic;
import lang.bytecode;
import lang.lib.io;
import lang.lib.sys;
import lang.lib.ctfe;
import lang.lib.func;

Pair[] rootCtfeBase()
{
    Dynamic load(Dynamic function(Args args) fn)
    {
        return dynamic(fn);
    }

    return [
        Pair("print", load(&lang.lib.ctfe.ctfelibprint)),
        Pair("read", load(&lang.lib.ctfe.ctfelibread)),
        Pair("run_entry", load(&lang.lib.ctfe.ctfelibentry)),
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

Pair[] getRootBase()
{
    Dynamic load(Dynamic function(Args args) fn)
    {
        return dynamic(fn);
    }

    return [
        Pair("print", load(&lang.lib.io.libprint)),
        Pair("put", load(&lang.lib.io.libput)),
        Pair("readln", load(&lang.lib.io.libreadln)),
        Pair("leave", load(&lang.lib.sys.libleave)),
        Pair("_both_map", load(&lang.lib.sys.libubothmap)),
        Pair("_lhs_map", load(&lang.lib.sys.libulhsmap)),
        Pair("_rhs_map", load(&lang.lib.sys.liburhsmap)),
        Pair("_pre_map", load(&lang.lib.sys.libupremap)),
        Pair("range", load(&lang.lib.func.librange)),
    ];
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

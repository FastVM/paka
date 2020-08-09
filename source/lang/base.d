module lang.base;

import lang.dynamic;
import lang.bytecode;
import lang.lib.io;
import lang.lib.sys;
import lang.lib.ffi;
import lang.lib.box;

struct Pair
{
    string name;
    Dynamic val;
}

Pair[][] rootBases;

ref Pair[] rootBase()
{
    return rootBases[$ - 1];
}

static this()
{
    rootBases ~= getRootBase;
}

void enterCtx()
{
    rootBases ~= getRootBase;
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
        Pair("symbol", load(&lang.lib.ffi.libselfload)),
        Pair("box", load(&lang.lib.box.libbox)),
        Pair("unbox", load(&lang.lib.box.libunbox)),
    ];
}

Function baseFunction()
{
    Function ret = new Function;
    ushort[string] byName;
    foreach (i; rootBase)
    {
        byName[i.name] = cast(ushort) byName.length;
    }
    string[] byPlace = ["print"];
    ret.stab = Function.Lookup(byName, byPlace);
    return ret;
}

string[Dynamic function(Args)] baseLookup()
{
    string[Dynamic function(Args)] ret;
    foreach (i; rootBase)
    {
        ret[i.val.fun.fun] = i.name;
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

module lang.base;

import lang.dynamic;
import lang.bytecode;
import lang.lib.io;
import lang.lib.serial;
import lang.lib.sys;

struct Pair
{
    string name;
    Dynamic val;
}

Pair[] rootBase;
Dynamic[string] rootFuncs;
string[Dynamic function(Args)] serialLookup;

static this()
{
    rootBase = getRootBase;
    serialLookup = baseLookup;
    rootFuncs = funcLookup;
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
        Pair("dumpf", load(&lang.lib.serial.libdumpf)),
        Pair("dump", load(&lang.lib.serial.libdump)),
        Pair("undump", load(&lang.lib.serial.libundump)),
        Pair("resumef", load(&lang.lib.serial.libresumef)),
        Pair("undumpf", load(&lang.lib.serial.libundumpf)),
        Pair("leave", load(&lang.lib.sys.libleave)),
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
        ret[i.val.value.fun.fun] = i.name;
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

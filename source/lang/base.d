module lang.base;

import lang.dynamic;
import lang.bytecode;
import lang.lib.io;
import lang.lib.serial;
import lang.lib.sys;
import lang.lib.str;
import lang.lib.arr;
import std.algorithm;
import std.stdio;

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
        dyn[dynamic(entry.name)] = entry.val;
    }
    pairs ~= Pair(name, dynamic(dyn));
}

Dynamic load(Dynamic function(Args args) fn)
{
    return dynamic(fn);
}

Pair[] getRootBase()
{
    Pair[] ret = [
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
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    // writeln(ret.map!(x => x.name));
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
    // string[] byPlace = ["print"];
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

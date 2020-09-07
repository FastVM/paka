module lang.lib.repl;

import lang.base;
import lang.dynamic;
import lang.vm;
import lang.serial;
import lang.json;
import std.conv;
import std.array;
import std.stdio;
import std.algorithm;

Pair[] librepl()
{
    Pair[] ret = [
        Pair("history", dynamic(&libhistory)), Pair("last",
                dynamic(&liblast)), Pair("local", dynamic(&liblocal)),
                Pair("locals", dynamic(&liblocals)),
    ];
    ret.addLib("config", libconfig);
    return ret;
}

private:
Dynamic libhistory(Args args)
{
    if (SerialValue* val = args[0].num.to!string in states)
    {
        return dynamic([
                dynamic("input"): dynamic((*val).object["input"].str),
                dynamic("output"): (*val).object["output"].readjs!Dynamic,
                ]);
    }
    throw new Exception("index out of range");
}

Dynamic liblast(Args args)
{
    if (states["length"].str == "0")
    {
        throw new Exception("no previous history");
    }
    SerialValue val = states[to!string(states["length"].str.to!size_t - 1)];
    return dynamic([
            dynamic("input"): dynamic(val.object["input"].str),
            dynamic("output"): val.object["output"].readjs!Dynamic,
            ]);
}

Dynamic liblocal(Args args)
{
    if (Dynamic* val = args[0].str in funcLookup)
    {
        return *val;
    }
    throw new Exception("local index out of range");
}

Dynamic liblocals(Args args)
{
    return dynamic(funcLookup.keys.array.filter!(x => !x.canFind('.')).map!(x => dynamic(x)).array);
}

Pair[] libconfig()
{
    Pair[] ret = [
        Pair("hints", dynamic(2 ^^ 12)), Pair("instrs", dynamic(2 ^^ 28)),
    ];
    return ret;
}

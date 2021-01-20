module ext.quest.std.array;

import std.conv;
import std.stdio;
import std.array;
import std.algorithm;
import purr.dynamic;
import core.memory;
import quest.dynamic;
import quest.qscope;
import quest.maker;
import quest.globals;

Dynamic arrayText(Args args)
{
    if (args[0].isList)
    {
        return "List".qdynamic;
    }
    string ret = "[";
    foreach (key, val; args[0].getValue.arr)
    {
        if (key != 0)
        {
            ret ~= ", ";
        }
        ret ~= val.to!string;
    }
    ret ~= "]";
    return ret.qdynamic;
}

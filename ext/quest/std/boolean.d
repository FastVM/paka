module quest.std.boolean;

import std.conv;
import std.stdio;
import std.algorithm;
import purr.dynamic;
import quest.qscope;
import quest.dynamic;
import quest.maker;
import quest.globals;

Dynamic booleanText(Args args)
{
    if (args[0].isNumber)
    {
        return "Boolean".qdynamic;
    }
    return args[0].tab.meta["val".dynamic].log.to!string.qdynamic;
}

Dynamic booleanNum(Args args)
{
    if (args[0].getBoolean)
    {
        return 1.qdynamic;
    }
    else {
        return 0.qdynamic;
    }
}

Dynamic booleanBool(Args args)
{
    return args[0].getBoolean.qdynamic;
}

Dynamic booleanNot(Args args)
{
    return args[0].getBoolean.qdynamic;
}

Dynamic booleanCmp(Args args)
{
    bool lhs = args[0].getBoolean;
    bool rhs = args[1].getBoolean;
    if (lhs < rhs) {
        return qdynamic(-1);
    } 
    if (lhs == rhs)
    {
        return 0.qdynamic;
    }
    return 1.qdynamic;
}

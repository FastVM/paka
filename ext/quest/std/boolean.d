module quest.std.boolean;

import std.conv;
import std.stdio;
import std.algorithm;
import lang.dynamic;
import quest.qscope;
import quest.dynamic;
import quest.maker;
import quest.globals;

Dynamic booleanText(Args args)
{
    if (args[0].tab is globalNumber)
    {
        return "Boolean".makeText;
    }
    return args[0].tab.meta["val".dynamic].log.to!string.makeText;
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
    return args[0].getBoolean.makeBoolean;
}

Dynamic booleanNot(Args args)
{
    return qdynamic(args[0].getBoolean);
}

Dynamic booleanCmp(Args args)
{
    bool lhs = args[0].getBoolean;
    bool rhs = args[1].getBoolean;
    if (lhs < rhs) {
        return makeNumber(-1);
    } 
    if (lhs == rhs)
    {
        return 0.makeNumber;
    }
    return 1.makeNumber;
}

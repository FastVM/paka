module lang.quest.std.object;

import std.conv;
import std.stdio;
import std.math;
import lang.error;
import lang.dynamic;
import lang.quest.maker;
import lang.quest.dynamic;
import lang.quest.qscope;
import lang.quest.globals;

Dynamic objectStrToAtText(Args args)
{
    if (args[0].tab is globalObject)
    {
        return "Object".dynamic;
    }
    Table tab = args[0].tab;
    Dynamic* str = "@text".qdynamic in tab;
    if (str !is null)
    {
        Dynamic res = (*str)(args);
        if (res.type == Dynamic.Type.tab)
        {
            return res.to!string.dynamic;
        }
        if (res.type == Dynamic.Type.str)
        {
            return res;
        }
        throw new TypeException("internal error: @text must return a String");
    }
    string ret;
    ret ~= "{";
    size_t i = 0;
    foreach (key, value; tab)
    {
        if (i != 0)
        {
            ret ~= ", ";
        }
        ret ~= key.to!string;
        ret ~= ": ";
        ret ~= value.to!string;
        i++;
    }
    ret ~= "}";
    return ret.dynamic;
}

Dynamic objectDotEquals(Args args)
{
    args[0].tab[args[1]] = args[2].getValue.qdynamic;
    return args[2];
}

Dynamic objectCmp(Args args)
{
    return args[0].opCmp(args[1]).makeNumber;
}

Dynamic objectMetaCmp(Args args)
{
    if (Dynamic* val = "<=>".qdynamic in args[0].tab)
    {
        return (*val)(args).getNumber.dynamic;
    }
    return args[0].opCmp(args[1]).dynamic;
}

Dynamic objectEq(Args args)
{
    return dynamic(args[0] == args[1]);
}

Dynamic objectNeq(Args args)
{
    return dynamic(args[0] != args[1]);
}

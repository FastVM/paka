module lang.quest.dynamic;

import std.conv;
import lang.dynamic;
import lang.quest.maker;

Dynamic qdynamic(T)(T arg) if (!is(T == Dynamic))
{
    return arg.dynamic.qdynamic;
}

Dynamic qdynamic(Dynamic val)
{
    switch (val.type)
    {
    default:
        throw new Exception("cannot make quest value from: " ~ val.to!string);
    case Dynamic.type.sml:
        return val.as!double.makeNumber;
    case Dynamic.type.str:
        return val.str.makeText;
    case Dynamic.type.fun:
        return val.makeFunction;
    case Dynamic.type.del:
        return val.makeFunction;
    case Dynamic.type.pro:
        return val.makeFunction;
    case Dynamic.type.nil:
        return makeNull;
    case Dynamic.type.tab:
        return val;
    }
}
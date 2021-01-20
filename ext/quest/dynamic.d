module quest.dynamic;

import std.stdio;
import std.conv;
import purr.dynamic;
import quest.maker;
import quest.globals;

bool isGlobalValue(alias globalv)(Dynamic val)
{
    return val.type == Dynamic.Type.tab && val.tab == globalv; 
}

alias isNumber = isGlobalValue!globalNumber;
alias isText = isGlobalValue!globalText;
alias isBoolean = isGlobalValue!globalBoolean;
alias isList = isGlobalValue!globalList;
alias isFunction = isGlobalValue!globalFunction;
alias isObject = isGlobalValue!globalObject;

Dynamic qstore(Dynamic tab, Dynamic to, Dynamic from)
{
    if (tab.type != Dynamic.Type.tab)
    {
        tab.deref = tab.deref.qtable;
    }
    tab.tab[to] = from;
    return from;
}

Dynamic qindex(Dynamic tab, Dynamic index)
{
    final switch (tab.typeImpl)
    {
    case Dynamic.Type.nil:
        return globalNull[index];
    case Dynamic.Type.log:
        return globalBoolean[index];
    case Dynamic.Type.sml:
        return globalNumber[index];
    case Dynamic.Type.str:
        return globalText[index];
    case Dynamic.Type.fun:
        return globalFunction[index];
    case Dynamic.Type.del:
        return globalFunction[index];
    case Dynamic.Type.pro:
        return globalFunction[index];
    case Dynamic.Type.arr:
        return globalList[index];
    case Dynamic.Type.tab:
        return tab.tab[index];
    case Dynamic.Type.ptr:
        return tab.deref.qindex(index);
    case Dynamic.Type.end:
        assert(false);
    case Dynamic.Type.pac:
        assert(false);
    }
}

Dynamic qdynamic(T)(T arg) if (!is(T == Dynamic))
{
    return arg.dynamic.qdynamic;
}

Dynamic qbox(Dynamic val)
{
    return dynamic(new Dynamic(val));
}

Dynamic qtable(Dynamic val)
{
    switch (val.type)
    {
    default:
        throw new Exception("cannot make quest value from: " ~ val.to!string);
    case Dynamic.Type.log:
        return val.log.makeBoolean;
    case Dynamic.Type.sml:
        return val.as!double.makeNumber;
    case Dynamic.Type.str:
        return val.str.makeText;
    case Dynamic.Type.fun:
        return val.makeFunction;
    case Dynamic.Type.del:
        return val.makeFunction;
    case Dynamic.Type.pro:
        return val.makeFunction;
    case Dynamic.Type.nil:
        return makeNull;
    case Dynamic.Type.arr:
        return val.arr.makeList;
    case Dynamic.Type.tab:
        return val;
    }
}

Dynamic qdynamic(Dynamic val)
{
    return val.qbox;
}
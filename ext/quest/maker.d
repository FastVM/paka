module quest.maker;

import std.stdio;
import purr.dynamic;
import quest.globals;
import quest.qscope;
import quest.dynamic;
import quest.std.null_;
import quest.std.number;
import quest.std.function_;
import quest.std.object;

Dynamic getValue(Dynamic arg)
{
    if (arg.type == Dynamic.Type.tab)
    {
        return arg.tab.meta["val".dynamic];
    }
    return arg;
}

void setValue(ref Dynamic arg, Dynamic val)
{
    arg.tab.meta["val".dynamic] = val;
}

string getString(Dynamic arg)
{
    return arg.getValue.str;
}

double getNumber(Dynamic arg)
{
    return arg.getValue.as!double;
}

bool getBoolean(Dynamic arg)
{
    return arg.getValue.log;
}

Dynamic makeText(string str)
{
    Mapping mapping = emptyMapping;
    mapping["val".dynamic] = str.dynamic;
    return new Table(emptyMapping, new Table(mapping).withProto(globalText)).dynamic;
}

Dynamic makeNumber(double num)
{
    Mapping mapping = emptyMapping;
    mapping["val".dynamic] = num.dynamic;
    Dynamic ret = new Table(emptyMapping, new Table(mapping).withProto(globalNumber)).dynamic;
    return ret;
}

Dynamic makeFunction(Dynamic fun)
{
    Mapping mapping = emptyMapping;
    Table ret = new Table(emptyMapping, new Table(mapping).withProto(globalFunction));
    mapping["val".dynamic] = fun;
    if (qScopes.length > 0)
    {
        mapping["scope".dynamic] = topScope.dynamic;
    }
    // if (qScopes.length == 0)
    // {
    //     mapping["scope".dynamic] = globalObject.dynamic;
    // }
    // else {
    //     mapping["scope".dynamic] = topScope.dynamic;
    // }
    mapping["call".dynamic] = (Args args) {
        return (*("val".dynamic in ret.meta.table))(args);
    }.dynamic;
    return ret.dynamic;
}

Dynamic makeList(Dynamic[] arr)
{
    Mapping mapping = emptyMapping;
    mapping["val".dynamic] = arr.dynamic;
    Dynamic ret = new Table(emptyMapping, new Table(mapping).withProto(globalList)).dynamic;
    return ret;
}

Dynamic makeNull()
{
    return globalNull.dynamic;
}

Dynamic makeBoolean(bool log)
{
    Mapping mapping = emptyMapping;
    mapping["val".dynamic] = log.dynamic;
    Dynamic ret = new Table(emptyMapping, new Table(mapping).withProto(globalBoolean)).dynamic;
    return ret;
}

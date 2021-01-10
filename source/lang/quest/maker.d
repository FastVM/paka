module lang.quest.maker;

import std.stdio;
import lang.dynamic;
import lang.quest.globals;
import lang.quest.qscope;
import lang.quest.dynamic;
import lang.quest.std.null_;
import lang.quest.std.number;
import lang.quest.std.function_;
import lang.quest.std.object;

Dynamic makeText(string str)
{
    Mapping mapping = emptyMapping;
    mapping["val".dynamic] = str.dynamic;
    return new Table(emptyMapping, new Table(mapping).withProto(globalText)).dynamic;
}

string getString(Dynamic arg)
{
    return arg.getValue.str;
}

Dynamic getValue(Dynamic arg)
{
    if (arg.type != Dynamic.Type.tab)
    {
        return arg;
    }
    return arg.tab.meta["val".dynamic];
}

Dynamic makeNumber(double num)
{
    Mapping mapping = emptyMapping;
    mapping["val".dynamic] = num.dynamic;
    Dynamic ret = new Table(emptyMapping, new Table(mapping).withProto(globalNumber)).dynamic;
    return ret;
}

void setValue(ref Dynamic arg, Dynamic val)
{
    arg.tab.meta["val".dynamic] = val;
}

double getNumber(Dynamic arg)
{
    return arg.getValue.as!double;
}

Dynamic makeFunction(Dynamic fun)
{
    Mapping mapping = emptyMapping;
    Table ret = new Table(emptyMapping, new Table(mapping).withProto(globalFunction));
    mapping["val".dynamic] = fun;
    if (qScopes.length == 0)
    {
        mapping["scope".dynamic] = globalObject.dynamic;
    }
    else {
        mapping["scope".dynamic] = qScopes[$-1].dynamic;
    }
    // mapping["str".dynamic] = dynamic(&functionStr);
    mapping["call".dynamic] = (Args args) {
        return (*("val".dynamic in ret.meta.table))(args);
    }.dynamic;
    return ret.dynamic;
}

Dynamic makeNull()
{
    // Mapping meta = emptyMapping;
    // meta["val".dynamic] = Dynamic.nil;
    // Dynamic ret = new Table(emptyMapping, new Table(meta).withProto(globalNull)).dynamic;
    return globalNull.dynamic;
}

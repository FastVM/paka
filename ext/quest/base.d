module quest.base;

import std.stdio;
import purr.base;
import purr.dynamic;
import quest.dynamic;
import quest.qscope;
import quest.globals;
import quest.maker;

Pair[] questBaseLibs()
{
    Pair[] ret;
    ret ~= Pair("_quest_load_current", &loadcurrent);
    ret ~= Pair("_quest_cons_value", &consvalue);
    ret ~= Pair("_quest_index", &index);
    ret ~= Pair("_quest_index_call", &indexcall);
    ret ~= Pair("_quest_index_index_call", &indexindexcall);
    ret ~= Pair("_quest_null", &qnull);
    ret ~= Pair("_quest_enter", &qenter);
    ret ~= Pair("_quest_exit", &qexit);
    ret ~= Pair("_quest_base_scope", &basescope);
    ret ~= Pair("_quest_colon", &colon);
    return ret;
}

private:

Dynamic qnull(Args args)
{
    return Dynamic.nil.qdynamic;
}

Dynamic loadcurrent(Args args)
{
    return topScope.dynamic;
}

Dynamic basescope(Args args)
{
    if (gscope is null)
    {
        return globalScope.dynamic;
    }
    return gscope.dynamic;
}

Dynamic qenter(Args args)
{
    qScopeEnter(args[0].tab);
    return qScopes[$-1].dynamic;
}

Dynamic qexit(Args args)
{
    qScopeExit;
    return args[$-1];
}

Dynamic colon(Args args)
{
    return qScopes[$ - cast(size_t) args[0].as!size_t - 1].dynamic;
}

Dynamic index(Args args)
{
    return args[0].qindex(args[1]);
}

Dynamic indexcall(Args args)
{
    return args[1].qindex(args[0])(args[1 .. $]);
}

Dynamic indexindexcall(Args args)
{
    return args[0].qindex(args[1])(args[0] ~ args[2 .. $]);
}

Dynamic consvalue(Args args)
{
    return args[0].qdynamic;
}

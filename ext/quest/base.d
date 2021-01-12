module quest.base;

import lang.base;
import lang.dynamic;
import quest.dynamic;
import quest.qscope;
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
    ret ~= Pair("_quest_colon", &colon);
    return ret;
}

private:

Dynamic qnull(Args args)
{
    return makeNull;
}

Dynamic loadcurrent(Args args)
{
    return topScope.dynamic;
}

Dynamic colon(Args args)
{
    return qScopes[$ - cast(size_t) args[0].as!size_t - 1].dynamic;
}

Dynamic index(Args args)
{
    return args[0].tab[args[1]];
}

Dynamic indexcall(Args args)
{
    return args[1].tab[args[0]](args[1 .. $]);
}

Dynamic indexindexcall(Args args)
{
    return args[0].tab[args[1]](args[0] ~ args[2 .. $]);
}

Dynamic consvalue(Args args)
{
    return args[0].qdynamic;
}

module quest.std.basic;

import lang.dynamic;
import quest.dynamic;
import quest.globals;
import quest.maker;

Dynamic basicMetaCmp(Args args)
{
    return args[0].getValue.opCmp(args[1].getValue).dynamic;
}

Dynamic basicBool(Args args)
{
    return true.qdynamic;
}
module lang.quest.std.comparable;

import std.conv;
import std.stdio;
import lang.dynamic;
import lang.quest.maker;
import lang.quest.qscope;
import lang.error;

Dynamic cmpLt(Args args)
{
    return dynamic(args[0] < args[1]);
}

Dynamic cmpGt(Args args)
{
    return dynamic(args[0] > args[1]);
}

Dynamic cmpLte(Args args)
{
    return dynamic(args[0] <= args[1]);
}

Dynamic cmpGte(Args args)
{
    return dynamic(args[0] >= args[1]);
}

module lang.quest.std.basic;

import lang.dynamic;
import lang.quest.dynamic;
import lang.quest.globals;
import lang.quest.maker;

Dynamic basicMetaCmp(Args args)
{
    return args[0].getValue.opCmp(args[1].getValue).dynamic;
}
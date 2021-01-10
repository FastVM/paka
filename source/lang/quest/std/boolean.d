module lang.quest.std.boolean;

import std.conv;
import std.stdio;
import std.algorithm;
import lang.dynamic;
import lang.quest.qscope;
import lang.quest.maker;
import lang.quest.globals;

Dynamic booleanText(Args args)
{
    if (args[0].tab is globalNumber)
    {
        return "Boolean".makeText;
    }
    return args[0].tab.meta["val".dynamic].log.to!string.makeText;
}


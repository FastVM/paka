module quest.std.text;

import std.stdio;
import std.conv;
import std.algorithm;
import lang.dynamic;
import quest.qscope;
import quest.dynamic;
import quest.maker;
import quest.globals;

Dynamic textText(Args args)
{
    if (args[0].tab is globalText)
    {
        return "String".makeText;
    }
    return args[0].tab.meta["val".dynamic].str.makeText;
}

Dynamic textMetaStr(Args args)
{
    if (args[0].tab is globalText)
    {
        return "String".dynamic;
    }
    return args[0].tab.meta["val".dynamic];
}

Dynamic textSet(Args args)
{
    return topScope[".=".qdynamic](topScope.dynamic ~ args);
}

Dynamic textAdd(Args args)
{
    return makeText(args[0].getString ~ args[1].getString);
}

Dynamic textCmp(Args args)
{
    string lhs = args[0].getString;
    string rhs = args[1].getString;
    if (lhs < rhs) {
        return makeNumber(-1);
    } 
    if (lhs == rhs)
    {
        return 0.makeNumber;
    }
    return 1.makeNumber;
}

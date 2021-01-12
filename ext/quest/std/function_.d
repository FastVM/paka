module quest.std.function_;

import std.conv;
import std.stdio;
import std.algorithm;
import lang.dynamic;
import quest.qscope;
import quest.maker;
import quest.globals;

Dynamic functionText(Args args)
{
    if (args[0].tab is globalFunction)
    {
        return "Function".makeText;
    }
    return makeText("Function(\"\")");
}

Dynamic functionCall(Args args)
{
    if (Dynamic* scope_ = "scope".dynamic in args[0].tab.meta)
    {
        qScopeEnter(scope_.tab, args[1..$]);
    }
    scope(exit)
    {
        qScopeExit;
    }
    if (args.length == 0) {
        return topScope.dynamic;
    }
    try
    {
        Dynamic ret = args[0](args[1 .. $]);
        return ret;
    }
    catch (ReturnValueFlowException rvfe)
    {
        if (rvfe.qscope is topScope)
        {
            return rvfe.value;
        }
        throw rvfe;
    }
}

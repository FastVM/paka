module quest.std.function_;

import std.conv;
import std.stdio;
import std.algorithm;
import purr.dynamic;
import quest.qscope;
import quest.maker;
import quest.globals;
import quest.dynamic;

Dynamic functionText(Args args)
{
    if (args[0].isFunction)
    {
        return "Function".qdynamic;
    }
    return qdynamic("Function(\"\")");
}

Dynamic functionCall(Args args)
{
    Dynamic fun = args[0];
    if (fun.type != Dynamic.Type.tab)
    {
        return fun(args[1..$]);
    }
    bool hasScope;
    if (Dynamic* scope_ = "scope".dynamic in fun.tab.meta)
    {
        qScopeEnter(scope_.tab, args[1..$]);
        hasScope = true;
    }
    scope(exit)
    {
        if (hasScope)
        {
            qScopeExit;
        }
    }
    if (args.length == 0) {
        return topScope.dynamic;
    }
    try
    {
        Dynamic ret = fun(args[1 .. $]);
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

module lang.lib.sysenv;

import lang.dynamic;
import lang.base;
import lang.vm;
import std.process;
import std.conv;

Pair[] libsysenv()
{
    Pair[] ret = [
        Pair("get", &libget), Pair("set", &libset),
        Pair("replace", &libreplace),
    ];
    return ret;
}

Dynamic libget(Args args)
{
    return dynamic(environment[args[0].str]);
}

Dynamic libset(Args args)
{
    environment[args[0].str] = args[1].to!string;
    return Dynamic.nil;
}

Dynamic libreplace(Args args)
{
    Dynamic ret = Dynamic.nil;
    if (args[0].str in environment)
    {
        ret = dynamic(environment[args[0].str]);
    }
    environment[args[0].str] = args[1].to!string;
    return ret;
}

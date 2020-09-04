module lang.lib.sysenv;

import lang.dynamic;
import lang.base;
import lang.vm;
import std.process;
import std.conv;

Pair[] libsysenv()
{
    Pair[] ret = [
        Pair("get", dynamic(&libget)), Pair("set", dynamic(&libset)),
        Pair("replace", dynamic(&libreplace)),
    ];
    return ret;
}

private:
Dynamic libget(Args args)
{
    ioUsed = true;
    if (args[0].str in environment)
    {
        return Dynamic.nil;
    }
    return dynamic(environment[args[0].str]);
}

Dynamic libset(Args args)
{
    if (!enableIo)
    {
        ioUsed = true;
        return Dynamic.nil;
    }
    environment[args[0].str] = args[1].to!string;
    return Dynamic.nil;
}

Dynamic libreplace(Args args)
{
    if (!enableIo)
    {
        ioUsed = true;
        maxLength = 0;
    }
    Dynamic ret = Dynamic.nil;
    if (args[0].str in environment)
    {
        ret = dynamic(environment[args[0].str]);
    }
    environment[args[0].str] = args[1].to!string;
    return ret;
}

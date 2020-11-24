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

void libget(Cont cont, Args args)
{
    cont(dynamic(environment[args[0].str]));
    return;
}

void libset(Cont cont, Args args)
{
    environment[args[0].str] = args[1].to!string;
    cont(Dynamic.nil);
    return;
}

void libreplace(Cont cont, Args args)
{
    Dynamic retv = Dynamic.nil;
    if (args[0].str in environment)
    {
        retv = dynamic(environment[args[0].str]);
    }
    environment[args[0].str] = args[1].to!string;
    cont(retv);
    return;
}

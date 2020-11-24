module lang.lib.io;

import lang.dynamic;
import lang.base;
import lang.vm;
import std.stdio;
import std.conv;
import core.stdc.stdio;

Pair[] libio()
{
    Pair[] ret = [
        Pair("print", &libprint),
        Pair("put", &libput),
        Pair("readln", &libreadln),
        Pair("get", &libget),
    ];
    return ret;
}

/// prints with newline
void libprint(Cont cont, Args args)
{
    foreach (i; args)
    {
        if (i.type == Dynamic.Type.str)
        {
            write(i.to!string[1..$-1]);
        }
        else
        {
            write(i);
        }
    }
    writeln;
    cont(Dynamic.nil);
    return;
}

/// prints without newline
void libput(Cont cont, Args args)
{
    foreach (i; args)
    {
        if (i.type == Dynamic.Type.str)
        {
            write(i.to!string[1..$-1]);
        }
        else
        {
            write(i);
        }
    }
    cont(Dynamic.nil);
    return;
}

/// reads until newline
void libreadln(Cont cont, Args args)
{
    cont(dynamic(readln[0 .. $ - 1]));
    return;
}

/// gets a 1 length string
void libget(Cont cont, Args args)
{
    cont(dynamic(cast(string) [cast(char) getchar]));
    return;
}

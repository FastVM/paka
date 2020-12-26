module lang.lib.io;

import lang.dynamic;
import lang.base;
import lang.vm;
import std.stdio;
import std.conv;
import std.file;
import core.stdc.stdio;

Pair[] libio()
{
    Pair[] ret = [
        Pair("print", &libprint),
        Pair("put", &libput),
        Pair("readln", &libreadln),
        Pair("get", &libget),
        Pair("slurp", &libslurp),
    ];
    return ret;
}

/// prints with newline
Dynamic libprint(Args args)
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
    return Dynamic.nil;
}

/// prints without newline
Dynamic libput(Args args)
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
    return Dynamic.nil;
}

/// reads until newline
Dynamic libreadln(Args args)
{
    return dynamic(readln[0 .. $ - 1]);
}

/// gets a 1 length string
Dynamic libget(Args args)
{
    return dynamic(cast(string) [cast(char) getchar]);
}

/// reads an entire file
Dynamic libslurp(Args args)
{
    return dynamic(cast(string) args[0].str.read);
}

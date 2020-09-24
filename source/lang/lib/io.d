module lang.lib.io;

import lang.dynamic;
import lang.base;
import lang.vm;
import std.stdio;
import std.conv;

Pair[] libio()
{
    Pair[] ret = [
        Pair("print", dynamic(&libprint)),
        Pair("put", dynamic(&libput)),
        Pair("readln", dynamic(&libreadln)),
    ];
    return ret;
}
private:

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

Dynamic libreadln(Args args)
{
    return dynamic(readln[0 .. $ - 1]);
}

module lang.lib.io;

import lang.dynamic;
import std.stdio;
import std.conv;

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

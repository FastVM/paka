module lang.lib.io;

import lang.dynamic;
import std.stdio;

Dynamic libprint(Args args)
{
    foreach (i; args)
    {
        write(i);
    }
    writeln;
    return Dynamic.nil;
}

Dynamic libput(Args args)
{
    foreach (i; args)
    {
        write(i);
    }
    return Dynamic.nil;
}

Dynamic libreadln(Args args)
{
    return dynamic(readln[0..$-1]);
}

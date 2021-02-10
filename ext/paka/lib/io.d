module paka.lib.io;

import purr.dynamic;
import purr.base;
import purr.vm;
import purr.fs.files;
import purr.fs.disk;
import std.stdio;
import std.conv;

Pair[] libio()
{
    Pair[] ret = [
        Pair("print", &libprint),
        Pair("put", &libput),
        Pair("readln", &libreadln),
        Pair("get", &libget),
        Pair("slurp", &libslurp),
        Pair("dump", &libdump),
        Pair("sync", &libsync),
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
    stdout.flush;
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

/// writes a string to a file
Dynamic libdump(Args args)
{
    args[0].str.dumpToFile(args[1].str);
    return Dynamic.nil;
}

/// sync file from filesystem
Dynamic libsync(Args args)
{
    return args[0].str.syncFile.dynamic;
} 
/// reads an entire file
Dynamic libslurp(Args args)
{
    return dynamic(cast(string) args[0].str.readFile.src);
}

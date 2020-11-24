module lang.lib.proc;

import lang.dynamic;
import lang.base;
import lang.error;
import std.typecons;
import std.process;
import std.algorithm;
import std.array;
import std.stdio;
import std.conv;
import core.memory;

Pair[] libproc()
{
    Pair[] ret = [
        Pair("system", &libsystem), Pair("shell", &libshell)
    ];
    return ret;
}

// TODO: replace this with wsl compatable version
/// evaluates command as arguments
void libsystem(Cont cont, Args args)
{
    string output = execute(args.map!(x => x.to!string).array).output;
    cont(dynamic(output));
    return;
}

// TODO: replace this with wsl compatable version
/// evaluates command as shell
void libshell(Cont cont, Args args)
{
    Tuple!(int, "status", string, "output") output = executeShell(args[0].str);
    if (output.status != 0)
    {
        throw new RuntimeException("shell error: " ~ output.output.to!string);
    }
    cont(dynamic(output.output));
    return;
}

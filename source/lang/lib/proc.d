module lang.lib.proc;

import lang.dynamic;
import lang.base;
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
        Pair("system", dynamic(&libsystem)), Pair("shell", dynamic(&libshell))
    ];
    return ret;
}

private:
Dynamic libsystem(Dynamic[] args)
{
    string output = execute(args.map!(x => x.to!string).array).output;
    return dynamic(output);
}

Dynamic libshell(Dynamic[] args)
{
    Tuple!(int, "status", string, "output") output = executeShell(args[0].str);
    if (output.status != 0)
    {
        throw new Exception("shell error: " ~ output.output.to!string);
    }
    return dynamic(output.output);
}

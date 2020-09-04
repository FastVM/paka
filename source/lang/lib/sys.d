module lang.lib.sys;

import lang.dynamic;
import lang.base;
import lang.lib.sysenv;
import core.stdc.stdlib;
import core.runtime;
import std.algorithm;
import std.array;

Pair[] libsys()
{
    Pair[] ret = [
        Pair("leave", dynamic(&libleave)), Pair("args", dynamic(&libargs)),
    ];
    ret.addLib("env", libsysenv);
    return ret;
}

private:
Dynamic libleave(Args args)
{
    if (!enableIo)
    {
        ioUsed = true;
        return Dynamic.nil;
    }
    throw new Exception("sys.leave was called");
}

Dynamic libargs(Args args)
{
    return dynamic(Runtime.args.map!(x => dynamic(x)).array);
}

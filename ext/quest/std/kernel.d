module quest.std.kernel;

import std.stdio;
import lang.dynamic;
import quest.maker;
import quest.qscope;

Dynamic globalDisp(Args args)
{
    foreach (key, val; args)
    {
        if (key != 0)
        {
            write(' ');
        }
        write(val);
    }
    writeln;
    return makeNull;
}

Dynamic globalDispn(Args args)
{
    foreach (key, val; args)
    {
        if (key != 0)
        {
            write(' ');
        }
        write(val);
    }
    return makeNull;
}

Dynamic globalReturn(Args args)
{
    if (args.length == 1) {
        throw new ReturnValueFlowException(args[0]);
    }
    throw new ReturnValueFlowException(args[0], args[1].tab);
}

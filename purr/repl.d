module purr.repl;

import purr.dynamic;
import purr.base;
import purr.io;

Pair[] librepl()
{
    Pair[] ret;
    ret ~= FunctionPair!libsmart("smart");
    return ret;
}

private:
Dynamic libsmart(Args args)
{
    if (args.length == 0)
    {
        return reader.smart.dynamic;
    }
    if (args.length >= 2)
    {
        throw new Exception("too many arguments");
    }
    makeReader(args[0].log);
    return Dynamic.nil;
}

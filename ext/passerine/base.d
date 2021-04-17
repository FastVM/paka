module passerine.base;

import std.file;
import std.conv;
import purr.io;
import purr.dynamic;
import purr.base;
import purr.inter;
import purr.srcloc;
import purr.error;
import purr.fs.disk;

Dynamic libprint(Dynamic[] args)
{
    writeln(args[0]);
    return args[0];
}

Pair[] passerineBaseLibs()
{
    Pair[] ret;
    ret ~= FunctionPair!libprint("print");
    return ret;
}

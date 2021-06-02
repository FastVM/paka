module ext.passerine.base;

import std.file;
import std.conv;
import purr.io;
import purr.dynamic;
import purr.base;
import purr.inter;
import purr.srcloc;
import purr.fs.disk;

Dynamic libprint(Dynamic[] args)
{
    foreach (arg; args) 
    {
        write(arg);
    }
    writeln;
    return args[$-1];
}

Dynamic libapply(Dynamic[] args)
{
    return args[0](args[1].arr);
}

Dynamic libawait(Dynamic[] args)
{
    return args[0].async!true;
}

Pair[] passerineBaseLibs()
{
    Pair[] ret;
    ret ~= FunctionPair!libapply("_pn_ffi_apply");
    ret ~= FunctionPair!libprint("print");
    ret ~= FunctionPair!libawait("await");
    return ret;
}

module ext.bind.bind;

import purr.io;
import std.json;
import purr.base;
import purr.dynamic;
import ext.bind.binder;
import ext.bind.libffi;

Pair[] ffilib()
{
    Pair[] ret;
    ret ~= FunctionPair!libdefs("defs");
    return ret;
}

Dynamic libdefs(Args args)
{
    JSONValue syms = bindings(args[0].str).parseJSON;
    Dynamic[] keys;
    foreach (key, value; syms.object)
    {
        keys ~= key.dynamic;
    }
    return keys.dynamic;
}

module paka.base;

import std.file;
import std.conv;
import purr.io;
import purr.dynamic;
import purr.base;
import purr.inter;
import purr.srcloc;
import purr.fs.disk;

/// string concatenate for format strings and unicode literals
Dynamic strconcat(Args args)
{
    string ret;
    foreach (arg; args)
    {
        if (arg.type == Dynamic.Type.str)
        {
            ret ~= arg.str;
        }
        else
        {
            ret ~= arg.to!string;
        }
    }
    return ret.dynamic;
}

Dynamic[string] libs;
Dynamic pakaimport(Args args)
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    string filename;
    foreach (key, arg; args)
    {
        if (key != 0)
        {
            filename ~= "/";
        }
        filename ~= arg.str;
    }
    string basename = filename;
    if (Dynamic* ret = basename in libs)
    {
        return *ret;
    }
    if (filename.fsexists)
    {
    }
    else if (fsexists(filename ~ ".paka"))
    {
        filename ~= ".paka";
    }
    else
    {
        throw new Exception("import error: cannot locate: " ~ filename);
    }
    Location data = filename.readFile;
    Dynamic val = ctx.eval(data);
    libs[basename] = val;
    return val;
}

Pair[] pakaBaseLibs()
{
    Pair[] ret;
    ret ~= FunctionPair!strconcat("_paka_str_concat");
    ret ~= FunctionPair!pakaimport("_paka_import");
    return ret;
}

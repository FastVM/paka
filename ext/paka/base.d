module paka.base;

import std.file;
import std.conv;
import purr.io;
import purr.dynamic;
import purr.base;
import purr.inter;
import purr.srcloc;
import purr.fs.disk;
import paka.lib.io;
import paka.lib.sys;
import paka.lib.str;
import paka.lib.arr;
import paka.lib.tab;
import paka.lib.math;

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
    // ret ~= FunctionPair!syslibubothmap("_paka_map_both");
    // ret ~= FunctionPair!syslibulhsmap("_paka_map_lhs");
    // ret ~= FunctionPair!sysliburhsmap("_paka_map_rhs");
    // ret ~= FunctionPair!syslibupremap("_paka_map_pre");
    // ret ~= FunctionPair!syslibfoldbinary("_paka_fold_binary");
    // ret ~= FunctionPair!syslibfoldunary("_paka_fold_unary");
    // ret ~= FunctionPair!syslibrange("_paka_range");
    ret ~= FunctionPair!strconcat("_paka_str_concat");
    ret ~= FunctionPair!pakaimport("_paka_import");
    ret.addLib("str", libstr);
    ret.addLib("arr", libarr);
    ret.addLib("tab", libtab);
    ret.addLib("io", libio);
    ret.addLib("sys", libsys);
    ret.addLib("math", libmath);
    return ret;
}

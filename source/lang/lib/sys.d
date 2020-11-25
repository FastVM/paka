module lang.lib.sys;

import lang.dynamic;
import lang.base;
import lang.lib.sysenv;
import lang.error;
import lang.ast;
import lang.parse;
import lang.walk;
import lang.vm;
import lang.inter;
import lang.bytecode;
import core.stdc.stdlib;
import core.runtime;
import std.algorithm;
import std.file;
import std.array;
import std.conv;
import std.stdio;
import std.parallelism : parallel;

Pair[] libsys()
{
    Pair[] ret = [
        Pair("leave", &libleave), Pair("args", &libargs),
        Pair("typeof", &libtypeof), Pair("import", &libimport),
        Pair("assert", &libassert), Pair("callcc", &libcallcc),
    ];
    ret.addLib("env", libsysenv);
    return ret;
}

/// asserts value is true, with error msg
void libassert(Cont cont, Args args)
{
    if (args[0].type == Dynamic.Type.nil || (args[0].type == Dynamic.Type.log && !args[0].log))
    {
        throw new AssertException("assert error: " ~ args[1].to!string);
    }
    cont(Dynamic.nil);
    return;
}

/// imports value returning what it returned
void libimport(Cont cont, Args args)
{
    string code = cast(string) args[0].str.read;
    Dynamic retval = evalFile(code);
    cont(retval);
    return;
};

/// returns type of value as a string
void libtypeof(Cont cont, Args args)
{
    final switch (args[0].type)
    {
    case Dynamic.Type.nil:
        cont(dynamic("nil"));
        return;
    case Dynamic.Type.log:
        cont(dynamic("logical"));
        return;
    case Dynamic.Type.sml:
        cont(dynamic("number"));
        return;
    case Dynamic.Type.big:
        cont(dynamic("number"));
        return;
    case Dynamic.Type.str:
        cont(dynamic("string"));
        return;
    case Dynamic.Type.arr:
        cont(dynamic("array"));
        return;
    case Dynamic.Type.tab:
        cont(dynamic("table"));
        return;
    case Dynamic.Type.fun:
        cont(dynamic("callable"));
        return;
    case Dynamic.Type.del:
        cont(dynamic("callable"));
        return;
    case Dynamic.Type.pro:
        cont(dynamic("callable"));
        return;
    case Dynamic.Type.end:
        assert(0);
    case Dynamic.Type.pac:
        assert(0);
    }
}

/// internal map function
void syslibubothmap(Cont cont, Args args)
{
    Array ret;
    size_t remain = args[1].arr.length;
    void newcont(Dynamic got)
    {
        ret ~= got;
        remain--;
        if (remain == 0)
        {
            cont(dynamic(ret));
            return;
        }
    }

    if (remain == 0)
    {
        cont(dynamic(cast(Dynamic[])[]));
        return;
    }
    foreach (i, v; args[1].arr)
    {
        args[0](&newcont, [v, args[2].arr[i]]);
    }
}

/// internal map function
void syslibulhsmap(Cont cont, Args args)
{
    Array ret;
    size_t remain = args[1].arr.length;
    void newcont(Dynamic got)
    {
        ret ~= got;
        remain--;
        if (remain == 0)
        {
            cont(dynamic(ret));
            return;
        }
    }

    if (remain == 0)
    {
        cont(dynamic(cast(Dynamic[])[]));
        return;
    }
    foreach (i; args[1].arr)
    {
        args[0](&newcont, [i, args[2]]);
    }
}

/// internal map function
void sysliburhsmap(Cont cont, Args args)
{
    Array ret;
    size_t remain = args[2].arr.length;
    void newcont(Dynamic got)
    {
        ret ~= got;
        remain--;
        if (remain == 0)
        {
            cont(dynamic(ret));
            return;
        }
    }

    if (remain == 0)
    {
        cont(dynamic(cast(Dynamic[])[]));
        return;
    }
    foreach (i; args[2].arr)
    {
        args[0](&newcont, [args[1], i]);
    }
}

/// internal map function
void syslibupremap(Cont cont, Args args)
{
    Array ret;
    size_t remain = args[1].arr.length;
    void newcont(Dynamic got)
    {
        ret ~= got;
        remain--;
        if (remain == 0)
        {
            cont(dynamic(ret));
            return;
        }
    }
    if (remain == 0)
    {
        cont(dynamic(cast(Dynamic[])[]));
        return;
    }
    foreach (i; args[1].arr)
    {
        args[0](&newcont, [i]);
    }
}

/// exit function
void libleave(Cont cont, Args args)
{
    exit(0);
    assert(0);
}

/// internal args
void libargs(Cont cont, Args args)
{
    cont(dynamic(Runtime.args.map!(x => dynamic(x)).array));
    return;
}

void libcallcc(Cont cont, Args args)
{
    Dynamic rec = void;
    void newCont(Cont c2, Args a2)
    {
        cont(a2[0]);
    }

    rec = dynamic(&newCont);
    args[0](cont, [rec]);
}

module lang.inter;

import std.traits;
import std.stdio;
import std.functional;
import std.conv;
import lang.vm;
import lang.dynamic;
import lang.parse;
import lang.base;
import lang.walk;
import lang.ast;
import lang.bytecode;

Dynamic toDynamic()
{
    return Dynamic.nil;
}

void fromDynamic(T)(Dynamic t) if (is(T == void))
{
    assert(t.type == Dynamic.Type.nil);
}

Dynamic toDynamic(Dynamic d)
{
    return d;
}

T fromDynamic(T)(Dynamic d) if (is(T == Dynamic))
{
    return d;
}

Dynamic toDynamic(T)(T v) if (isNumeric!T)
{
    return dynamic(v);
}

T fromDynamic(T)(Dynamic v) if (isNumeric!T)
{
    return cast(T) v.num;
}

Dynamic toDynamic(T)(T[] v)
{
    Dynamic[] ret;
    foreach (i; v)
    {
        ret ~= i.toDynamic;
    }
    return dynamic(ret);
}

T fromDynamid(T)(Dynamic v) if (isArray!T)
{
    T ret;
    foreach (i, v; v.arr)
    {
        ret ~= v.fromDynamic!(ForeachType!T);
    }
    return ret;
}

Dynamic[] toDynamicArray(T...)(T args)
{
    Dynamic[] ret;
    static foreach (arg; args)
    {
        ret ~= arg.toDynamic;
    }
    return ret;
}

Dynamic toDynamic(R, A...)(R function(A) arg)
{
    return toDelegate(arg).toDynamic;
}

T fromDynamic(T)(Dynamic v) if (isDelegate!T)
{
    alias Ret = ReturnType!T;
    alias Args = Parameters!T;
    return cast(Ret delegate(Args))(Args args) {
        Dynamic[] dargs = toDynamicArray!Args(args);
        switch (v.type)
        {
        default:
            assert(0);
        case Dynamic.Type.pro:
            return run(v.fun.pro, dargs).fromDynamic!Ret;
        case Dynamic.Type.del:
            return (*v.fun.del)(dargs).fromDynamic!Ret;
        case Dynamic.Type.fun:
            return v.fun.fun(dargs).fromDynamic!Ret;
        }
    };
}

Dynamic overload(A...)(A args) {
    return dynamic((Dynamic[] args) {

    });
}

Dynamic toDynamic(Ret, Args...)(Ret delegate(Args) del)
{
    return dynamic((Dynamic[] dargs) {
        Args args;
        foreach (i, Arg; Args)
        {
            args[i] = dargs[i].fromDynamic!(Arg);
        }
        if (is(Ret == void))
        {
            del(args);
        }
        else
        {
            return del(args).toDynamic;
        }
    });
}

T evalTo(T, A...)(string code, A args) if ((A.length == 1 && isAssociativeArray!(A[0])) || A.length % 2 == 0)
{
    Node node = code.parse;
    Walker walker = new Walker;
    enterCtx;
    scope(exit) exitCtx;
    static if (A.length == 1)
    {
        static foreach (i; A[0].byKeyValue)
        {
            defineRoot(i.key.to!string, i.value.toDynamic);
        }
    }
    else
    {
        static foreach (i; 0 .. A.length / 2)
        {
            defineRoot(args[i * 2].to!string, args[i * 2 + 1].toDynamic);
        }
    }
    Function func = walker.walkProgram(node);
    func.captured = loadBase;
    return run(func).fromDynamic!T;
}

Dynamic eval(A...)(string code, A args)
{
    return evalTo!Dynamic(code, args);
}

static this()
{
}

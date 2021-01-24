module purr.inter;

import std.typecons;
import std.traits;
import std.stdio;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import purr.vm;
import purr.walk;
import purr.ir.walk;
import purr.bc.dump;
import purr.bytecode;
import purr.base;
import purr.ast;
import purr.dynamic;
import purr.parse;
import purr.vm;
import purr.inter;

/// vm callback that sets the locals defined into the root base 
LocalCallback exportLocalsToBaseCallback(Function func)
{
    LocalCallback ret = (uint index, Dynamic* stack, Dynamic[] locals) {
        foreach (i, v; locals[0 .. func.stab.length])
        {
            rootBase ~= Pair(func.stab[i], v);
        }
    };
    return ret;
}

bool dumpbytecode = false;
bool usenewir = false;

Dynamic evalImpl(Walker)(size_t ctx, string code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = ctx.loadBase;
    if (dumpbytecode)
    {
        OpcodePrinter oppr = new OpcodePrinter;
        oppr.walk(func);
        writeln(oppr.ret);
    }
    Dynamic retval = run(func, null, func.exportLocalsToBaseCallback);
    return retval;
}

Dynamic eval(size_t ctx, string code)
{
    if (usenewir)
    {
        return evalImpl!(purr.ir.walk.Walker)(ctx, code);
    }
    else
    {
        return evalImpl!(purr.walk.Walker)(ctx, code);
    }
}

Dynamic evalFileImpl(Walker)(string code)
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = loadBase;
    if (dumpbytecode)
    {
        OpcodePrinter oppr = new OpcodePrinter;
        oppr.walk(func);
        writeln(oppr.ret);
    }
    Dynamic retval = run(func);
    return retval;
}

Dynamic evalFile(string code)
{
    if (usenewir)
    {
        return evalFileImpl!(purr.ir.walk.Walker)(code);
    }
    else
    {
        return evalFileImpl!(purr.walk.Walker)(code);
    }
}


void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

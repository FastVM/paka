module purr.inter;

import std.typecons;
import std.traits;
import std.stdio;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import purr.vm;
import purr.bc.dump;
import purr.bytecode;
import purr.base;
import purr.ast;
import purr.dynamic;
import purr.parse;
import purr.vm;
import purr.inter;
import purr.srcloc;
import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;

bool dumpbytecode = false;

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

Dynamic evalImpl(Walker)(size_t ctx, Location code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    BasicBlock bb = walker.bbwalk(node);
    Function func = walker.walkProgram(node, ctx);
    if (dumpbytecode)
    {
        OpcodePrinter oppr = new OpcodePrinter;
        oppr.walk(func);
        writeln(oppr.ret);
    }
    Dynamic retval = run(func, null, func.exportLocalsToBaseCallback);
    return retval;
}

Dynamic eval(size_t ctx, Location code)
{
    return evalImpl!(purr.ir.walk.Walker)(ctx, code);
}

Dynamic evalFileImpl(Walker)(Location code)
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    if (dumpbytecode)
    {
        OpcodePrinter oppr = new OpcodePrinter;
        oppr.walk(func);
        writeln(oppr.ret);
    }
    Dynamic retval = run(func);
    return retval;
}

Dynamic evalFile(Location code)
{
    return evalFileImpl!(purr.ir.walk.Walker)(code);
}


void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

module purr.inter;

import std.typecons;
import std.traits;
import purr.io;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import purr.vm;
import purr.bc.dump;
import purr.bytecode;
import purr.base;
import purr.ast.ast;
import purr.dynamic;
import purr.parse;
import purr.vm;
import purr.async;
import purr.inter;
import purr.srcloc;
import purr.ir.repr;
import purr.ir.walk;

__gshared bool dumpbytecode = false;
__gshared bool dumpir = false;

/// vm callback that sets the locals defined into the root base 
LocalCallback exportLocalsToBaseFormback(size_t ctx, Bytecode func)
{
    LocalCallback ret = (uint index, Dynamic[] locals) {
        most: foreach (i, v; locals)
        {
            foreach (ref rb; rootBases[ctx])
            {
                if (rb.name == func.stab[i])
                {
                    rb.val = v;
                    continue most;
                }
            }
            rootBases[ctx] ~= Pair(func.stab[i], v);
        }
    };
    return ret;
} 

Dynamic evalImpl(Walker)(size_t ctx, SrcLoc code, Args args)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Bytecode func = walker.walkProgram(node, ctx);
    if (dumpbytecode)
    {
        OpcodePrinter oppr = new OpcodePrinter;
        oppr.walk(func);
        writeln(oppr.ret);
    }
    scope(success)
    {
        stopAllAsyncCalls;
    }
    return run(func, args, ctx.exportLocalsToBaseFormback(func));
}

Dynamic eval(size_t ctx, SrcLoc code, Args args=new Dynamic[0])
{
    return evalImpl!(purr.ir.walk.Walker)(ctx, code, args);
}

void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

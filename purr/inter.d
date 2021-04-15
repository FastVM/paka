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
import purr.inter;
import purr.srcloc;
import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;

__gshared bool dumpbytecode = false;
__gshared bool dumpir = false;

/// vm callback that sets the locals defined into the root base 
LocalCallback exportLocalsToBaseCallback(size_t ctx, Function func)
{
    LocalCallback ret = (uint index, Dynamic* stack, Dynamic[] locals) {
        most: foreach (i, v; locals[0 .. func.stab.length])
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

Dynamic evalImpl(Walker)(size_t ctx, Location code, Args args)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    if (dumpbytecode)
    {
        OpcodePrinter oppr = new OpcodePrinter;
        oppr.walk(func);
        writeln(oppr.ret);
    }
    return run(func, args, ctx.exportLocalsToBaseCallback(func));
}

Dynamic eval(size_t ctx, Location code, Args args=Args.init)
{
    return evalImpl!(purr.ir.walk.Walker)(ctx, code, args);
}

void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

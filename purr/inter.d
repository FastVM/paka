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
bool runjit = false;

/// vm callback that sets the locals defined into the root base 
LocalCallback exportLocalsToBaseCallback(Function func)
{
    LocalCallback ret = (uint index, Dynamic* stack, Dynamic[] locals) {
        most: foreach (i, v; locals[0 .. func.stab.length])
        {
            foreach (ref rb; rootBase)
            {
                if (rb.name == func.stab[i])
                {
                    rb.val = v;
                    continue most;
                }
            }
            rootBase ~= Pair(func.stab[i], v);
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
    if (runjit && func.jitted !is null)
    {
        func.jitted();
        return Dynamic.nil;
    }
    else
    {
        return run(func, args, func.exportLocalsToBaseCallback);
    }
}

Dynamic eval(size_t ctx, Location code, Args args=Args.init)
{
    return evalImpl!(purr.ir.walk.Walker)(ctx, code, args);
}

void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

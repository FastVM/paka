module purr.inter;

import std.typecons;
import std.traits;
import purr.io;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import purr.vm;
import purr.vm.bytecode;
import purr.ast.ast;
import purr.dynamic;
import purr.parse;
import purr.vm;
import purr.inter;
import purr.srcloc;
import purr.ir.repr;
import purr.ir.walk;

__gshared bool dumpir = false;

Dynamic evalImpl(Walker)(SrcLoc code, Args args)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Bytecode func = walker.walkProgram(node);
    return run(func, args);
}

Dynamic eval(SrcLoc code, Args args=new Dynamic[0])
{
    return evalImpl!(purr.ir.walk.Walker)(code, args);
}


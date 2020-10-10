module lang.inter;

import std.traits;
import std.stdio;
import std.functional;
import std.conv;
import lang.vm;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.ast;
import lang.dynamic;
import lang.dext.parse;
import lang.vm;
import lang.inter;
import lang.dext.repl;

Dynamic eval(size_t ctx, string code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = ctx.loadBase;
    return run(func, [func.exportLocalsToBaseCallback]);
}

void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

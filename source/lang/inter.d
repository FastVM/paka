module lang.inter;

import std.typecons;
import std.traits;
import std.stdio;
import std.functional;
import std.conv;
import std.algorithm;
import std.meta;
import lang.vm;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.ast;
import lang.dynamic;
import lang.parse;
import lang.vm;
import lang.inter;
import lang.dext.repl;
import lang.bc.dump;
import lang.bc.parse;
import lang.bc.typer;
import lang.bc.compiler;

Dynamic eval(size_t ctx, string code)
{
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = ctx.loadBase;
    Dynamic retval = run(func, null, func.exportLocalsToBaseCallback);
    return retval;
}

string dis(Function func) {
    OpcodePrinter iter = new OpcodePrinter;
    iter.walk(func);
    return iter.ret;
}

void ptypes(Function func) {
    TypeGenerator iter = new TypeGenerator;
    iter.walk(func);
    writeln;
}

string dis(size_t ctx, string code) {
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = ctx.loadBase;
    func.ptypes;
    string disd = func.dis;
    return disd;
}

Dynamic evalFile(string code)
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
    Dynamic retval = run(func);
    return retval;
}

void define(T)(size_t ctx, string name, T value)
{
    ctx.rootBase ~= Pair(name, value.toDynamic);
}

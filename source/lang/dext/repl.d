module lang.dext.repl;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.ast;
import lang.dynamic;
import lang.dext.parse;
import lang.vm;
import lang.inter;
import std.stdio;
import std.algorithm;
import std.string;
import std.functional;

LocalCallback printTopCallback;

LocalCallback exportLocalsToBaseCallback(Function func)
{
    LocalCallback ret = (ref size_t index, ref size_t depth,
            ref Dynamic[] stack, ref Dynamic[] locals) {
        foreach (i, ref v; locals[0 .. func.stab.byPlace.length])
        {
            rootBase ~= Pair(func.stab.byPlace[i], v);
        }
    };
    return ret;
}

void printTop(ref size_t index, ref size_t depth, ref Dynamic[] stack, ref Dynamic[] locals)
{
    writeln(stack[depth]);
}

void replRun()
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    while (true)
    {
        write(">>> ");
        string code = readln.strip;
        Node node = code.parse;
        Walker walker = new Walker;
        Function func = walker.walkProgram(node, ctx);
        func.captured = loadBase;
        run(func, toDelegate(&printTop), func.exportLocalsToBaseCallback);
    }
}

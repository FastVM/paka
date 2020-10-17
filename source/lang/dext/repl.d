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

/// vm callback that sets the locals defined into the root base 
LocalCallback exportLocalsToBaseCallback(Function func)
{
    LocalCallback ret = (uint index,
        Dynamic* stack, Dynamic[] locals) {
        foreach (i, v; locals[0 .. func.stab.byPlace.length])
        {
            rootBase ~= Pair(func.stab.byPlace[i], v);
        }
    };
    return ret;
}

/// vm callback that prints the top of the stack for the end of the repl
void printTop(uint index,
        Dynamic* stack, Dynamic[] locals)
{
    writeln(*stack);
}

/// runs a repl for dext language
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
        code ~= ";";
        Node node = code.parse;
        Walker walker = new Walker;
        Function func = walker.walkProgram(node, ctx);
        func.captured = loadBase;
        run(func, null, func.exportLocalsToBaseCallback, toDelegate(&printTop));
    }
}

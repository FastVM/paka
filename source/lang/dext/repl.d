module lang.dext.repl;
import lang.walk;
import lang.bytecode;
import lang.base;
import lang.ast;
import lang.dynamic;
import lang.dext.parse;
import lang.vm;
import lang.inter;
import lang.atext;
import std.stdio;
import std.algorithm;
import std.string;
import std.functional;

/// vm callback that sets the locals defined into the root base 
LocalCallback exportLocalsToBaseCallback(Function func)
{
    LocalCallback ret = (uint index, Dynamic* stack, Dynamic[] locals) {
        foreach (i, v; locals[0 .. func.stab.byPlace.length])
        {
            rootBase ~= Pair(func.stab.byPlace[i], v);
        }
    };
    return ret;
}

/// runs a repl for dext language
void replRun()
{
    char[][] history;
    Reader reader = new Reader(history);
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    while (true)
    {
        string code;
        try
        {
            code = reader.readln(">>> ");
        }
        catch (ExitException ee)
        {
            if (ee.letter == 'c') {
                continue;
            }
            writeln;
            break;
        }
        code ~= ";";
        Node node = code.parse;
        Walker walker = new Walker;
        Function func = walker.walkProgram(node, ctx);
        func.captured = loadBase;
        Dynamic res = run(func, null, func.exportLocalsToBaseCallback);
        if (res.type != Dynamic.Type.nil) {
            writeln(res, '\r');
        }
    }
}

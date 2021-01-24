module paka.repl;
import purr.walk;
import purr.bytecode;
import purr.base;
import purr.ast;
import purr.dynamic;
import purr.parse;
import purr.vm;
import purr.inter;
import purr.atext;
import std.stdio;
import std.algorithm;
import std.string;
import std.functional;

Node replParse(string arg)
{
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    Node node = arg.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram(node, ctx);
    func.captured = loadBase;
    Dynamic res = run(func, null, func.exportLocalsToBaseCallback);
    if (res.type != Dynamic.Type.nil)
    {
        writeln(res);
    }
    ctx.replRun;
    return null;
}

/// runs a repl for paka language
void replRun(size_t ctx)
{
    char[][] history;
    Reader reader = new Reader(history);
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
            writeln(res);
        }
    }
}

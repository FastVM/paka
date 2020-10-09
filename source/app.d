import lang.vm;
import lang.base;
import lang.walk;
import lang.ast;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.parse;
import lang.number;
import lang.inter;
import lang.dext.repl;
import gc.special;
import std.file;
import std.stdio;
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import core.memory;

// extern (C) __gshared bool rt_cmdline_enabled = false;
// extern (C) __gshared string[] rt_options = ["heapSizeFactor:8"];

enum string getstr(string code)()
{
    Node node = code.parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram!true(node);
    func.captured = loadCtfeBase;
    Dynamic retval = run(func);
    return retval.to!string;
}

alias ctfeRun = getstr;

enum string getfile(string file)()
{
    Node node = import(file).parse;
    Walker walker = new Walker;
    Function func = walker.walkProgram!true(node);
    func.captured = loadCtfeBase;
    Dynamic retval = run(func);
    return retval.to!string;
}

void main(string[] args)
{
    string[] scripts;
    string[] stmts;
    bool repl = false;
    auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
            &scripts, "math", &fastMathNotEnabled);
    if (info.helpWanted)
    {
        defaultGetoptPrinter("Help for 9c language.", info.options);
        return;
    }
    foreach (i; stmts)
    {
        size_t ctx = enterCtx;
        scope (exit)
        {
            exitCtx;
        }
        Node node = i.parse;
        Walker walker = new Walker;
        Function func = walker.walkProgram(node, ctx);
        func.captured = loadBase;
        Dynamic retval = run(func);
        if (retval.type != Dynamic.Type.nil)
        {
            writeln(retval);
        }
    }
    foreach (i; scripts ~ args[1 .. $])
    {
        size_t ctx = enterCtx;
        scope (exit)
        {
            exitCtx;
        }
        string code = cast(string) i.read;
        Node node = code.parse;
        Walker walker = new Walker;
        Function func = walker.walkProgram(node, ctx);
        func.captured = loadBase;
        run(func);
    }
    if ((scripts ~ args[1 .. $]).length == 0)
    {
        replRun;
        // while (true)
        // {
        //     size_t ctx = enterCtx;
        //     scope (exit)
        //     {
        //         exitCtx;
        //     }
        //     write(">>> ");
        //     string code = cast(string) readln;
        //     Node node = code.parse;
        //     Walker walker = new Walker;
        //     Function func = walker.walkProgram(node, ctx);
        //     func.captured = loadBase;
        //     Dynamic retval = run(func);
        //     if (retval.type != Dynamic.Type.nil)
        //     {
        //         writeln(retval);
        //     }
        // }
    }
}

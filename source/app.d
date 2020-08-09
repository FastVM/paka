import lang.vm;
import lang.base;
import lang.walk;
import lang.ast;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.parse;
import lang.typed;
import lang.repl;
import lang.inter;
import lang.data.ffi;
import std.file;
import std.stdio;
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import core.memory;

void main(string[] args)
{
    string[] scripts;
    string[] stmts;
    bool repl = false;
    auto info = getopt(args, "repl", &repl, "eval", &stmts, "file", &scripts);
    if (info.helpWanted)
    {
        defaultGetoptPrinter("Help for 9c language.", info.options);
        return;
    }
    foreach (i; stmts)
    {
        Node node = i.parse;
        Walker walker = new Walker;
        Function func = walker.walkProgram(node);
        func.captured = loadBase;
        Dynamic retval = void;
        retval = run(func);
        if (retval.type != Dynamic.Type.nil)
        {
            writeln(retval);
        }
    }
    foreach (i; scripts ~ args[1 .. $])
    {
        string code = cast(string) i.read;
        Node node = code.parse;
        // Typer typer = new Typer;
        // typer.annot(node);
        Walker walker = new Walker;
        Function func = walker.walkProgram(node);
        func.captured = loadBase;
        run(func);
    }
    if (repl || (args.length == 1 && scripts.length == 0 && stmts.length == 0))
    {
		replRun;
        // while (true)
        // {
        // 	try
        // 	{
        // 		write(">>> ");
        // 		string code = readln.strip;
        // 		if (code.length == 0)
        // 		{
        // 			continue;
        // 		}
        // 		code = code;
        // 		Node node = code.parse;
        // 		Walker walker = new Walker;
        // 		Function func = walker.walkProgram(node);
        // 		func.captured = loadBase;
        // 		Dynamic retval = void;
        // 		retval = run(func);
        // 		if (retval.type != Dynamic.Type.nil)
        // 		{
        // 			writeln(retval);
        // 		}
        // 		foreach (i, ref v; glocals)
        // 		{
        // 			rootBase ~= Pair(func.stab.byPlace[i], v);
        // 		}
        // 	}
        // 	catch (Exception e)
        // 	{
        // 		writeln(e.msg);
        // 	}
        // }
    }
}

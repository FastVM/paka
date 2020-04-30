import lang.vm;
import lang.base;
import lang.walk;
import lang.ast;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.parse;
import lang.serial;
import std.file;
import std.stdio;
import std.json;
import std.conv;
import std.string;
import std.getopt;
import core.memory;

void main(string[] args)
{
	string[] scripts;
	string[] stmts;
	bool repl = false;
	bool carry = false;
	auto info = getopt(args, "repl", &repl, "eval", &stmts, "file", &scripts, "base", &carry);
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
		Dynamic retval = run!true(func, null);
		if (retval.type != Dynamic.Type.nil)
		{
			writeln(retval);
		}
		if (carry)
		{
			foreach (j, ref v; glocals)
			{
				rootBase ~= Pair(func.stab.byPlace[j], v);
			}
		}
	}
	foreach (i; scripts ~ args[1..$])
	{
		string code = cast(string) i.read;
		Node node = code.parse;
		Walker walker = new Walker;
		Function func = walker.walkProgram(node);
		func.captured = loadBase;
		run(func, null);
	}
	if (repl || args.length == 1)
	{
		while (true)
		{
			try
			{
				write(">>> ");
				string code = readln.strip;
				if (code.length == 0)
				{
					continue;
				}
				code = code;
				Node node = code.parse;
				Walker walker = new Walker;
				Function func = walker.walkProgram(node);
				func.captured = loadBase;
				Dynamic retval = run!true(func, null);
				if (retval.type != Dynamic.Type.nil)
				{
					writeln(retval);
				}
				File f = File("world/repl.json", "w");
				f.write(saveState);
				foreach (i, ref v; glocals)
				{
					rootBase ~= Pair(func.stab.byPlace[i], v);
				}
			}
			catch (Exception e)
			{
				writeln(e.msg);
			}
		}
	}
}

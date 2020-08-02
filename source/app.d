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
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import core.memory;

extern (C) __gshared string[] rt_options = ["scanDataSeg=precise"];

void main(string[] args)
{
	string[] scripts;
	string[] stmts;
	bool save = false;
	bool repl = false;
	bool carry = false;
	ubyte vm = 1;
	string world = "world/repl.json";
	auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
			&scripts, "caarry", &carry, "json", &world, "save", &save, "vm", &vm);
	if (info.helpWanted)
	{
		defaultGetoptPrinter("Help for 9c language.", info.options);
		return;
	}
	Dynamic runfn(bool a, bool b, bool c)(Function func, Args args)
	{
		if (vm == 1)
		{
			return run1!(a, b, c)(func, args);
		}
		// else if (vm == 2)
		// {
		// 	return run2!(a, b, c)(func, args);
		// }
		throw new Exception("bad vm version must be 1");
	}

	if (save)
	{
		if (world.length != 0)
		{
			File f = File(world, "w");
			f.write(saveState);
		}
		if ("world/vm".exists)
		{
			"world/vm".rmdirRecurse;
		}
		"world/vm".mkdir;
	}
	foreach (i; stmts)
	{
		Node node = i.parse;
		Walker walker = new Walker;
		Function func = walker.walkProgram(node);
		func.captured = loadBase;
		Dynamic retval = void;
		if (save)
		{
			retval = runfn!(true, true, true)(func, null);
		}
		else
		{
			retval = runfn!(true, true, false)(func, null);
		}
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
	foreach (i; scripts ~ args[1 .. $])
	{
		string code = cast(string) i.read;
		if (i.length > 5 && i[$ - 5 .. $] == ".json")
		{
			loadState(code.parseJSON);
			runfn!(true, false, false)(null, null);
			save = false;
		}
		else
		{
			Node node = code.parse;
			Walker walker = new Walker;
			Function func = walker.walkProgram(node);
			func.captured = loadBase;
			if (save)
			{
				runfn!(false, true, true)(func, null);
			}
			else
			{
				runfn!(false, true, false)(func, null);
			}
		}
	}
	if (repl || (args.length == 1 && scripts.length == 0 && stmts.length == 0))
	{
		while (true)
		{
			try
			{
				if (world.exists)
				{
					string js = cast(string) world.read;
					if (js.length != 0)
					{
						loadState(js.parseJSON);
					}
				}
				write(">>> ");
				string code = readln.strip;
				if (code.length == 0)
				{
					File f = File(world, "w");
					f.write(saveState);
					continue;
				}
				code = code;
				Node node = code.parse;
				Walker walker = new Walker;
				Function func = walker.walkProgram(node);
				func.captured = loadBase;
				Dynamic retval = void;
				if (save)
				{
					retval = runfn!(true, true, true)(func, null);
				}
				else
				{
					retval = runfn!(true, true, false)(func, null);
				}
				if (retval.type != Dynamic.Type.nil)
				{
					writeln(retval);
				}
				foreach (i, ref v; glocals)
				{
					rootBase ~= Pair(func.stab.byPlace[i], v);
				}
				File f = File(world, "w");
				f.write(saveState);
			}
			catch (Exception e)
			{
				writeln(e.msg);
			}
		}
	}
}

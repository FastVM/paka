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

void main(string[] args)
{
	string[] scripts;
	string[] stmts;
	bool repl = false;
	bool carry = false;
	string world;
	auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
			&scripts, "caarry", &carry, "json", &world);
	repl = repl || (args.length == 1 && scripts.length == 0 && stmts.length == 0);
	if (world.length == 0 && repl)
	{
		world = "world/repl.json";
	}
	if (info.helpWanted)
	{
		defaultGetoptPrinter("Help for 9c language.", info.options);
		return;
	}
	// if (clean)
	// {
	// 	if (world.length != 0)
	// 	{
	// 		File f = File(world, "w");
	// 		f.write(saveState);
	// 	}
	// 	if ("world/vm".exists)
	// 	{
	// 		"world/vm".rmdirRecurse;
	// 	}
	// 	"world/vm".mkdirRecurse;
	// }
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
	foreach (i; scripts ~ args[1 .. $])
	{
		string code = cast(string) i.read;
		if (i.length > 5 && i[$ - 5 .. $] == ".json")
		{
			loadState(code.parseJSON);
			run!(true, false)(null, null, 0);
		}
		else
		{
			Node node = code.parse;
			Walker walker = new Walker;
			Function func = walker.walkProgram(node);
			func.captured = loadBase;
			run(func, null, 0);
		}
	}
	if (repl)
	{
		while (true)
		{
			if (world.length != 0 && world.exists)
			{
				string js = cast(string) world.read;
				if (js.length != 0)
				{
					loadState(js.parseJSON);
				}
			}
			write(">>> ");
			string code = readln.strip;
			if (world.length != 0 && code.length == 0)
			{
				File f = File(world, "w");
				f.write(saveState.toPrettyString);
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
			foreach (i, ref v; glocals)
			{
				rootBase ~= Pair(func.stab.byPlace[i], v);
			}
			File f = File(world, "w");
			f.write(saveState);
		}
	}
}

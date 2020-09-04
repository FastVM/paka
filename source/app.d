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
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import core.memory;
import core.stdc.stdlib;
import deimos.linenoise;
import lang.json;

size_t hintc = 2 ^^ 12;
size_t instrc = 2 ^^ 24;

extern (C) void linenoiseSetHintsCallback(char* function(const char*, int* color, int* bold));

extern (C) char* hints(const(char*) buf, int* color, int* bold)
{
	string bufStr = cast(string) buf.fromStringz;
	if (bufStr.length > 0 && bufStr[0] == '/' || hintc == 0)
	{
		return cast(char*) "".toStringz;
	}
	try
	{
		size_t old = maxLength;
		maxLength = vmRecord + hintc;
		scope (exit)
		{
			maxLength = old;
		}
		ioUsed = false;
		enableIo = false;
		SerialValue state = saveState;
		Node node = bufStr.parse;
		Walker walker = new Walker;
		Function func = walker.walkProgram(node);
		func.captured = loadBase;
		Dynamic retval = run!true(func);
		state.loadState;
		enableIo = true;
		*color = 90;
		if (retval == Dynamic.nil)
		{
			if (ioUsed)
			{
				return cast(char*) " => (Side Effect)";
			}
			return cast(char*) "".toStringz;
		}
		string side;
		if (ioUsed)
		{
			side = " => (Side Effect)";
		}
		return cast(char*) toStringz(side ~ " => " ~ retval.to!string);
	}
	catch (Exception e)
	{
		*color = 90;
		return cast(char*) " => error".toStringz;
	}
}

string getLine(size_t n)
{
	linenoiseSetMultiLine(1);
	linenoiseSetHintsCallback(&hints);
	char* line = linenoise(cast(char*) toStringz("(" ~ n.to!string ~ ")> "));
	if (line == null)
	{
		return "";
	}
	linenoiseHistoryAdd(line);
	string ret = cast(string) line.fromStringz;
	return ret;
}

void main(string[] args)
{
	GC.disable;
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
	foreach (i; stmts)
	{
		Node node = i.parse;
		Walker walker = new Walker;
		Function func = walker.walkProgram(node);
		func.captured = loadBase;
		Dynamic retval = run!true(func);
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
			loadState(code.serialParse);
			run!(true, false)(null, 0);
		}
		else
		{
			Node node = code.parse;
			Walker walker = new Walker;
			Function func = walker.walkProgram(node);
			func.captured = loadBase;
			run(func, 0);
		}
	}
	if (repl)
	{
		if (".repl_dext".exists)
		{
			linenoiseHistoryLoad(".repl_dext");
		}
		states["length"] = SerialValue("0");
		if (world.length != 0 && world.exists)
		{
			string js = cast(string) world.read;
			if (js.length != 0)
			{
				states = js.serialParse.object;
			}
		}
		if (states["length"].str.to!double < 0)
		{
			states["length"].str = "0";
		}
		else if (states["length"].str.to!double > 0)
		{
			size_t n = states["length"].str.to!size_t - 1;
			loadState(states[n.to!string].object["state"]);
		}
		double[2] prev = [2 ^^ 12, 2 ^^ 24];
		while (true)
		{
			Table* replTable = funcLookup["repl"].tabPtr;
			Table config = (*replTable)[dynamic("config")].tab;
			double hintcDouble = config[dynamic("hints")].num;
			double instrcDouble = config[dynamic("instrs")].num;
			if (hintcDouble < 0)
			{
				writeln("repl.config.hints: too low");
				hintcDouble = prev[0];
			}
			else
			{
				hintc = hintcDouble.to!size_t;
			}
			if (instrcDouble < 16)
			{
				writeln("repl.config.instrs: too low");
				hintcDouble = prev[1];
			}
			else
			{
				instrc = instrcDouble.to!size_t;
			}
			prev = [hintcDouble, instrcDouble];
			size_t old = maxLength;
			maxLength = vmRecord + instrc;
			scope (exit)
			{
				maxLength = old;
			}
			string code = getLine(states["length"].str.to!size_t).strip;
			if (code == "/quit" || code == "/exit")
			{
				return;
			}
			if (code.startsWith("/goto "))
			{
				states["length"].str = to!string(code["/undo ".length .. $].to!size_t);
				File f = File(world, "w");
				f.write(SerialValue(states).toPrettyString);
				size_t n = states["length"].str.to!size_t - 1;
				rootBase.length = 0;
				loadState(states[n.to!string].object["state"]);
				continue;
			}
			if (code == "/undo")
			{
				states["length"].str = to!string(states["length"].str.to!size_t - 1);
				File f = File(world, "w");
				f.write(SerialValue(states).toPrettyString);
				size_t n = states["length"].str.to!size_t - 1;
				rootBase.length = 0;
				loadState(states[n.to!string].object["state"]);
				continue;
			}
			if (code.length == 0)
			{
				continue;
			}
			Node node = code.parse;
			Walker walker = new Walker;
			Function func = walker.walkProgram(node);
			func.captured = loadBase;
			Dynamic retval = run!true(func);
			linenoiseHistorySave(".repl_dext");
			if (retval.type != Dynamic.Type.nil)
			{
				writeln(retval);
			}
			foreach (i, ref v; glocals)
			{
				rootBase ~= Pair(func.stab.byPlace[i], v);
			}

			size_t len = states["length"].str.to!size_t;
			states[len.to!string] = SerialValue([
					"state": saveState,
					"input": SerialValue(code),
					"output": retval.js
					]);
			states["length"].str = to!string(len + 1);
			File f = File(world, "w");
			f.write(SerialValue(states).toPrettyString);
			loadState(states[len.to!string].object["state"]);
		}
	}
}

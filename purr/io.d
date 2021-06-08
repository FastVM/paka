module purr.io;

import std.algorithm;
import std.string;
import std.array;
import std.range;
import std.conv;
import core.stdc.ctype;
import core.sync.mutex;

static import std.stdio;

alias File = std.stdio.File;
alias stdin = std.stdio.stdin;
alias stdout = std.stdio.stdout;
alias stderr = std.stdio.stderr;

__gshared Mutex ioLock;
__gshared Mutex ioLineLock;

shared static this()
{
	ioLock = new Mutex;
	ioLineLock = new Mutex;
}

char getchar()
{
	char ret;
	stdin.readf!"%c"(ret);
	return ret;
}

string readln(string prompt)
{
	write(prompt);
	return cast(string) stdin.readln ~ "\n";
}

void write1s(string str)
{
	foreach (chr; str)
	{
		synchronized(ioLock)
		{
			stdout.write(chr);
		}
	}
}

void write(Args...)(Args args)
{
	static foreach (arg; args)
	{
		write1s(arg.to!string);
	}
}

void writeln(Args...)(Args args)
{
	write(args, '\n');
}
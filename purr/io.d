module purr.io;

import std.algorithm;
import std.process;
import std.string;
import std.array;
import std.range;
import std.conv;
import core.stdc.stdlib;
import core.stdc.ctype;
// import core.sys.posix.termios;
import core.sys.posix.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;

static import std.stdio;

alias File = std.stdio.File;
alias stdin = std.stdio.stdin;
alias stdout = std.stdio.stdout;
alias stderr = std.stdio.stderr;

char readchar()
{
	char ret = stdin.readKeyAbs;
	write(ret);
	return ret;
}

char getchar()
{
	return stdin.readKeyAbs;
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
		std.stdio.write(chr);
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

char readKeyAbs(File f)
{
	char c;
	read(f.fileno, &c, 1);
	return c;
}

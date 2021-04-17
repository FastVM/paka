module purr.io;

import std.algorithm;
import std.process;
import std.string;
import std.array;
import std.range;
import std.conv;
import core.stdc.stdlib;
import core.stdc.ctype;
import core.sys.posix.termios;
import core.sys.posix.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;

static import std.stdio;

alias File = std.stdio.File;
alias stdin = std.stdio.stdin;
alias stdout = std.stdio.stdout;
alias stderr = std.stdio.stderr;

// enum string newline = "\x1B[1E";
__gshared Reader reader;
__gshared termios init;

shared static this()
{
	makeReader(true);
}

void makeReader(bool smart)
{
	synchronized
	{
		reader = new Reader(null);
		reader.smart = smart;
		if (reader.smart)
		{
			tcgetattr(stdin.fileno, &init);
			termios raw;
			tcgetattr(stdin.fileno, &raw);
			raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
			raw.c_oflag &= ~(OPOST);
			raw.c_cflag |= (CS8);
			raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
			tcsetattr(stdin.fileno, TCSAFLUSH, &raw);
			atexit(&purr_disable_smart_reader);
		}
	}
}

extern(C)
void purr_disable_smart_reader()
{
	tcsetattr(stdin.fileno, TCSAFLUSH, &init);
}

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
	return cast(string) reader.readln(prompt) ~ "\n";
}

void write1s(string str)
{
	foreach (chr; str)
	{
		if (chr == '\n' && reader.smart)
		{
			std.stdio.write("\r\n");
		}
		else
		{
			std.stdio.write(chr);
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

class ExitException : Exception
{
	char letter;
	this(char l)
	{
		letter = [getCtrl(l)].toUpper[0];
		super("Got Ctrl-" ~ letter);
	}
}

class Reader
{
	char[][] history;
	File input;
	File output;
	long index = 0;
	size_t histIndex = 0;
	bool smart = false;
	string prefix;
	this(char[][] h, File i = stdin, File o = stdout)
	{
		history = h ~ [[]];
		input = i;
		output = o;
	}

	private ref char[] line()
	{
		return history[histIndex];
	}

	private void renderLine(T)(T newLine)
	{
		output.write("\x1B[K\x1B[1F\x1B[1B");
		output.write(prefix, newLine);
		output.write("\x1B[" ~ to!string(prefix.length + index + 1) ~ "G");
		output.flush;
		
	}

	private void deleteOne()
	{
		if (index > 0)
		{
			line = line[0 .. index - 1] ~ line[index .. $];
			index--;
		}
		else
		{
			line = null;
		}
		renderLine(line);
	}

	private bool delegate() getWordFunc()
	{
		if (index < line.length && line[index] == ' ')
		{
			return { return canFind(" ", line[index]); };
		}
		else if (index < line.length && canFind("()", line[index]))
		{
			return { return canFind("()", line[index]); };
		}
		else
		{
			return { return !canFind(" ()", line[index]); };
		}
	}

	private void leftWord()
	{
		if (index > 0)
		{
			index--;
		}
		bool delegate() func = getWordFunc;
		while (index >= 0)
		{
			if (func())
			{
				index--;
			}
			else
			{
				break;
			}
		}
		index++;
	}

	private void rightWord()
	{
		bool delegate() func = getWordFunc;
		while (index < line.length)
		{
			if (func())
			{
				index++;
			}
			else
			{
				break;
			}
		}
	}

	private void reset()
	{
		index = 0;
		histIndex = 0;
	}

	char[] read(size_t maxlen = size_t.max)
	{
		reset;
		char[][] oldHistory;
		foreach (historyLine; history)
		{
			oldHistory ~= historyLine.dup;
		}
		input.flush;
		output.flush;
		histIndex = history.length;
		history ~= new char[0];
		char got = input.readKeyAbs;
		renderLine(line);
		while (true)
		{
			if (got == 0)
			{
				exit(0);
			}
			if (got == 27)
			{
				got = input.readKeyAbs;
				if (got == '[')
				{
					got = input.readKeyAbs;
					if (got == '1')
					{
						got = input.readKeyAbs;
						if (got == ';')
						{
							got = input.readKeyAbs;
							if (got == '5')
							{
								got = input.readKeyAbs;
								if (got == 'C')
								{
									rightWord;
								}
								if (got == 'D')
								{
									leftWord;
								}
							}
						}
					}
					else
					{
						if (got == 'C')
						{
							if (index < line.length)
							{
								index++;
							}
						}
						if (got == 'D')
						{
							if (index > 0)
							{
								index--;
							}
						}
						if (got == 'A')
						{
							renderLine(' '.repeat.take(line.length));
							if (histIndex > 0)
							{
								histIndex--;
							}
							index = line.length;
						}
						if (got == 'B')
						{
							renderLine(' '.repeat.take(line.length));
							if (histIndex < history.length - 1)
							{
								histIndex++;
							}
							index = line.length;
						}
					}
					renderLine(line);
				}
				renderLine(line);
			}
			else if (got == 127)
			{
				deleteOne;
				renderLine(line);
			}
			else if (iscntrl(got))
			{
				if (getCtrl(got) == 'm')
				{
					break;
				}
				else if (getCtrl(got) == 'r')
				{
					char[] ln;
					renderLine(ln);
					break;
				}
				else if (getCtrl(got) == 'j')
				{
					return line;
				}
				else
				{
					throw new ExitException(got);
				}
			}
			else
			{
				if (index >= line.length)
				{
					if (line.length >= maxlen)
					{
						return line;
					}
					line ~= got;
				}
				else
				{
					history[histIndex] = line[0 .. index] ~ [got] ~ line[index .. $];
				}
				index++;
				renderLine(line);
			}
			got = input.readKeyAbs;
		}
		if (oldHistory.length == 0 || oldHistory[$ - 1] != line)
		{
			oldHistory ~= line;
		}
		return line;
	}

	char[] readln(string prompt = null)
	{
		prefix = prompt;
		output.write(prompt);
		if (smart)
		{
			char[] read = read;
			output.write("\r\n");
			return read;
		}
		else
		{
			string ret = input.readln;
			return ret.strip.to!string.dup;
		}
	}
}

char getCtrl(char c)
{
	return cast(char)(c - 1 + 'a');
}

char readKeyAbs(File f)
{
	char c;
	read(f.fileno, &c, 1);
	return c;
}

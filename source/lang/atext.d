module lang.atext;

import std.algorithm;
import std.process;
import std.string;
import std.stdio;
import std.array;
import std.range;
import std.conv;
import core.stdc.stdlib;
import core.stdc.ctype;
import core.sys.posix.termios;
import core.sys.posix.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;

class ExitException : Exception
{
	char letter;
	this(char l)
	{
		letter = l;
		super("Got Ctrl-" ~ [l]);
	}
}

class Reader
{
	char[][] history;
	File input;
	File output;
	termios term;
	long index = 0;
	long lastRender = 0;
	size_t histIndex = 0;
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
		foreach (i; 0 .. lastRender)
		{
			output.moveLeft;
		}
		foreach (i; 0 .. newLine.length + 1)
		{
			output.moveRight;
			output.printStill!false(' ');
		}
		foreach (i; 0 .. newLine.length + 1)
		{
			output.moveLeft;
		}
		output.printStill!false(newLine);
		lastRender = index;
		foreach (i; 0 .. lastRender)
		{
			output.moveRight;
		}
	}

	private void deleteOne()
	{
		if (index > 0)
		{
			history[histIndex] = line[0 .. index - 1] ~ line[index .. $];
			index--;
		}
		else
		{
			history[histIndex] = null;
		}
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
		lastRender = 0;
		histIndex = 0;
	}

	string read()
	{
		reset;
		char[][] oldHistory;
		term = input.rawMode;
		foreach (historyLine; history)
		{
			oldHistory ~= historyLine.dup;
		}
		input.flush;
		output.flush;
		histIndex = history.length;
		history ~= new char[0];
		char got = input.readKeyAbs;
		scope (exit)
		{
			foreach (i; 0 .. index)
			{
				output.moveLeft;
			}
			input.noRawMode(term);
			output.write('\r');
			output.flush;
			history = oldHistory;
		}
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
					output.clearScreen;
					return read;
				}
				else if (getCtrl(got) == 'd')
				{
					input.noRawMode(term);
					exit(0);
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
		return cast(string) history[$ - 1];
	}

	string readln(string prompt = null)
	{
		output.write(prompt);
		string ret = read;
		output.writeln;
		return ret;
	}
}

char getCtrl(char c)
{
	return cast(char)(c - 1 + 'a');
}

void noRawMode(File inf, termios initTermios)
{
	tcsetattr(inf.fileno, TCSAFLUSH, &initTermios);
}

termios rawMode(File inf)
{
	termios initTermios;
	tcgetattr(inf.fileno, &initTermios);
	termios raw = initTermios;
	raw.c_iflag &= ~(BRKINT | ICRNL | INPCK | ISTRIP | IXON);
	raw.c_oflag &= ~(OPOST);
	raw.c_cflag |= (CS8);
	raw.c_lflag &= ~(ECHO | ICANON | IEXTEN | ISIG);
	tcsetattr(inf.fileno, TCSAFLUSH, &raw);
	return initTermios;
}

char readKeyAbs(File f)
{
	char c;
	read(f.fileno, &c, 1);
	return c;
}

void moveLeft(File f)
{
	f.write("\x1b[1D");
	f.flush;
}

void moveRight(File f)
{
	f.write("\x1b[1C");
	f.flush;
}

void clearScreen(File f)
{
	f.printStill("\x1b[2J");
}

void printStill(bool fl=true, T...)(File output, T as)
{
	size_t count;
	foreach (a; as)
	{
		string got = a.to!string;
		output.write(got);
		count += got.length;
	}
	foreach (i; 0 .. count)
	{
		output.moveLeft;
	}
	static if (fl) {
		output.flush;
	}
}
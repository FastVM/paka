module lang.ssize;

import std.stdio;
import lang.bytecode;

void resizeStack(Function func)
{
    writeln(func.instrs.length);
    foreach (i, ref v; func.instrs)
    {
    }
}

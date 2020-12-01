import lang.vm;
import lang.base;
import lang.walk;
import lang.ast;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.parse;
import lang.number;
import lang.inter;
import lang.bytecode;
import std.file;
import std.stdio;
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import std.parallelism : totalCPUs;
import core.memory;

LocalCallback exportLocalsToBaseCallback(Function func)
{
    return (Dynamic[] locals) {
        foreach (i, ref v; locals[0 .. func.stab.byPlace.length])
        {
            rootBase ~= Pair(func.stab.byPlace[i], v);
        }
    };
}

/// the actual main function, it does not handle errors
void domain(string[] args)
{
    version (threads)
    {
        cpuThreadsSpec = totalCPUs;
        size_t cpuThreadsSpecLocal = 0;
    }
    string[] scripts;
    string[] stmts;
    bool repl = false;
    version (threads)
    {
        version (bigfloat)
        {
            auto info = getopt(args, "repl", &repl, "eval", &stmts, "file", &scripts, "math",
                    &fastMathNotEnabled, "threads", &cpuThreadsSpecLocal);
        }
        else
        {
            auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
                    &scripts, "threads", &cpuThreadsSpecLocal);
        }
    }
    else
    {
        version (bigfloat)
        {
            auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
                    &scripts, "math", &fastMathNotEnabled);
        }
        else
        {
            auto info = getopt(args, "repl", &repl, "eval", &stmts, "file", &scripts);
        }
    }
    if (info.helpWanted)
    {
        defaultGetoptPrinter("Help for dext language.", info.options);
        return;
    }
    version (threads)
    {
        if (cpuThreadsSpecLocal != 0)
        {
            cpuThreadsSpec = cpuThreadsSpecLocal;
        }
    }
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    foreach (i; stmts)
    {
        Dynamic retval = ctx.eval(i);
        if (retval.type != Dynamic.Type.nil)
        {
            writeln(retval);
        }
    }
    foreach (i; scripts ~ args[1 .. $])
    {
        Dynamic retval = ctx.eval(cast(string) i.read);
        if (retval.type != Dynamic.Type.nil)
        {
            writeln(retval);
        }
    }
    if (scripts.length == 0 && args[1 .. $].length == 0)
    {
        while (true)
        {
            write(">>> ");
            string code = readln.strip;
            code ~= "\n;";
            Node node = code.parse;
            Walker walker = new Walker;
            Function func = walker.walkProgram(node, ctx);
            func.captured = loadBase;
            loopRun(delegate(Dynamic d) {
                if (d != Dynamic.nil)
                {
                    writeln(d);
                }
            }, func, null, func.exportLocalsToBaseCallback);
        }
    }
}

/// the main function that handles runtime errors
void trymain(string[] args)
{
    try
    {
        domain(args);
    }
    catch (Exception e)
    {
        size_t[] nums;
        size_t[] times;
        size_t ml = 0;
        foreach (i; spans)
        {
            if (nums.length != 0 && nums[$ - 1] == i.first.line)
            {
                times[$ - 1]++;
            }
            else
            {
                nums ~= i.first.line;
                times ~= 1;
                ml = max(ml, i.first.line.to!string.length);
            }
        }
        string ret = "error on \n";
        foreach (i, v; nums)
        {
            if (i == 0)
            {
                ret ~= "line";
            }
            else
            {
                ret ~= "from";
            }
            foreach (j; 0 .. ml.to!string.length - v.to!string.length + 2)
            {
                ret ~= " ";
            }
            ret ~= v.to!string;
            if (times[i] > 2)
            {
                ret ~= " (repeated: " ~ times[i].to!string ~ " times)";
            }
            ret ~= "\n";
        }
        spans.length = 0;
        e.msg = "\n" ~ ret ~ e.msg;
        throw e;
    }
}

void main(string[] args)
{
    trymain(args);
}

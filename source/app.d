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
import std.file;
import std.stdio;
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import core.memory;

/// the actual main function, it does not handle errors
void domain(string[] args)
{
    string[] scripts;
    string[] stmts;
    bool repl = false;
    auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
            &scripts, "math", &fastMathNotEnabled);
    if (info.helpWanted)
    {
        defaultGetoptPrinter("Help for 9c language.", info.options);
        return;
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

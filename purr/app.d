module purr.app;

import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;
import purr.vm;
import purr.srcloc;
import purr.base;
import purr.ast;
import purr.base;
import purr.dynamic;
import purr.parse;
import purr.inter;
import purr.plugin.loader;
import purr.fs.files;
import std.uuid;
import std.path;
import std.stdio;
import std.array;
import std.file;
import std.algorithm;
import std.process;
import std.conv;
import std.string;
import std.getopt;
import core.stdc.stdlib;

/// the actual main function, it does not handle errors
void domain(string[] args)
{
    string[] scripts;
    string[] stmts;
    string[] langs;
    string lnd = "paka";
    bool repl = true;
    bool echo = false;
    auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
            &scripts, "echo", &echo, "load", &langs, "lang", &lnd, "bytecode", &dumpbytecode);
    if (info.helpWanted)
    {
        defaultGetoptPrinter("Help for 9c language.", info.options);
        return;
    }
    langNameDefault = lnd;
    foreach (i; langs)
    {
        linkLang(i);
    }
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    scripts ~= args[1 .. $];
    foreach (i; stmts)
    {
        Dynamic retval = ctx.eval(Location(1, 1, "__main__", i ~ ";"));
        if (echo)
        {
            writeln(retval);
        }
    }
    foreach (i; scripts)
    {
        Location code = i.readFile;
        string cdir = getcwd;
        scope (exit)
        {
            cdir.chdir;
        }
        i.dirName.chdir;
        Dynamic retval = ctx.eval(code);
        if (echo)
        {
            writeln(retval);
        }
    }
    if (repl && (scripts.length == 0 && stmts.length == 0))
    {
        parse(Location(1, 1, "__main__"), langNameDefault ~ ".repl");
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
        string[] files;
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
                files ~= i.first.file;
                times ~= 1;
                ml = max(ml, i.first.line.to!string.length);
            }
        }
        string trace;
        string last = "__main__";
        foreach (i, v; nums)
        {
            if (i == 0)
            {
                trace ~= "  on line ";
            }
            else
            {
                trace ~= "from line ";
            }
            foreach (j; 0 .. ml - v.to!string.length)
            {
                trace ~= " ";
            }
            trace ~= v.to!string;
            if (files[i] != last)
            {
                last = files[i];
                trace ~= " (file: " ~ last ~ ")";
            }
            if (times[i] > 2)
            {
                trace ~= " (repeated: " ~ times[i].to!string ~ " times)";
            }
            trace ~= "\n";
        }
        spans.length = 0;
        writeln(trace);
        writeln(e.msg);
        writeln;
    }
}

void main(string[] args)
{
    trymain(args);
}

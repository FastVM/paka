import lang.vm;
import lang.base;
import lang.walk;
import lang.ast;
import lang.bytecode;
import lang.base;
import lang.dynamic;
import lang.parse;
import lang.inter;
import lang.dext.repl;
import lang.plugin.loader;
import std.file;
import std.path;
import std.stdio;
import std.process;
import std.algorithm;
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
    string[] search;
    bool repl = false;
    bool disWanted = false;
    bool echo = false;
    auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
            &scripts, "dis", &disWanted, "echo", &echo, "load", &langs, "path", &search);
    if (info.helpWanted)
    {
        defaultGetoptPrinter("Help for 9c language.", info.options);
        return;  
    }
    string libpathold = environment["LD_LIBRARY_PATH"];
    string libpathnew = libpathold;
    foreach (i; search)
    {
        libpathnew ~= ":";
        libpathnew ~= i;
    }
    environment["LD_LIBRARY_PATH"] = libpathnew;
    foreach (name; langs)
    {
        linkLang("libdext_" ~ name ~ ".so");
    }
    environment["LD_LIBRARY_PATH"] = libpathold;
    size_t ctx = enterCtx;
    scope (exit)
    {
        exitCtx;
    }
    foreach (i; stmts)
    {
        if (disWanted) {
            writeln(ctx.dis(i ~ ";"));
        }
        else {
            Dynamic retval = ctx.eval(i ~ ";");
            if (echo && retval.type != Dynamic.Type.nil)
            {
                writeln(retval);
            }
        }
    }
    foreach (i; scripts ~ args[1 .. $])
    {
        if (disWanted) {
            writeln(ctx.dis(cast(string) i.read ~ ";"));
        }
        else {
            string cdir = getcwd;
            scope (exit)
            {
                cdir.chdir;
            }
            string code = cast(string) i.read;
            i.dirName.chdir;
            Dynamic retval = ctx.eval(code);
            if (echo && retval.type != Dynamic.Type.nil)
            {
                writeln(retval);
            }
        }
    }
    if (((scripts ~ args[1 .. $]).length == 0 || repl) && !disWanted)
    {
        replRun;
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

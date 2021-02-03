module purr.app;

import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;
import purr.ir.native;
import purr.vm;
import purr.base;
import purr.ast;
import purr.base;
import purr.dynamic;
import purr.parse;
import purr.inter;
import purr.plugin.loader;
import std.file;
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
    string compilerArg = null;
    string dFlagsArg;
    string doOptArg = "0";
    auto info = getopt(args, "repl", &repl, "eval", &stmts, "file",
            &scripts, "echo", &echo, "load", &langs, "lang", &lnd, "bytecode",
            &dumpbytecode, "compiler", &compilerArg, "flags", &dFlagsArg, "opt", &doOptArg);
    string[] dFlags = dFlagsArg.splitter(" ").array;
    string[] compiler = compilerArg.splitter(" ").array;
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
        Dynamic retval = ctx.eval(i ~ ";");
        if (echo && retval.type != Dynamic.Type.nil)
        {
            writeln(retval);
        }
    }
    foreach (i; scripts)
    {
        string code = cast(string) i.read;
        if (compiler != null)
        {
            Node node = code.parse;
            Walker walker = new Walker;
            BasicBlock bb = walker.bbwalk(node);
            Generator gen = new NativeBackend;
            if (".purr".exists)
            {
                if (!".purr".isDir)
                {
                    throw new Exception(".purr is not a directory, delete it and make it one");
                }
            }
            else
            {
                ".purr".mkdir;
            }
            gen.emitAsFunc(bb);
            UUID id = randomUUID;
            string dfile = ".purr/" ~ id.to!string ~ ".d";
            // string exefile = ".purr/" ~ id.to!string ~ ".exe";
            string exefile = "out.exe";
            File file = File(dfile, "w");
            file.writeln(gen.repr);
            file.close;
            string[] opt;
            string o;
            if (compiler[0].canFind("dmd"))
            {
                opt = null;
                o = "-of";
                compiler ~= "-L-export-dynamic";
            }
            else if (compiler[0].canFind("ldc"))
            {
                opt = ["-O" ~ doOptArg, "-release"];
                o = "-of";
                compiler ~= "-L-export-dynamic";
            }
            else if (compiler[0].canFind("gdc"))
            {
                opt = ["-O" ~ doOptArg, "-frelease"];
                o = "-o";
                compiler ~= "-export-dynamic";
            }
            else
            {
                throw new Exception("cannot compile with --compiler=" ~ compilerArg);
            }
            writeln("spawning compiler");
            DirEntry[] purrDirEntries = "purr/".dirEntries(SpanMode.breadth).array;
            string[] purrSrcPaths;
            string[] programs = ["purr/app.d"];
            foreach (entry; purrDirEntries)
            {
                if (!entry.isDir && entry.name.length > 2
                        && entry.name[$ - 2 .. $] == ".d" && !programs.canFind(entry.name))
                {
                    purrSrcPaths ~= entry.name;
                }
            }
            auto comp = execute(compiler ~ [dfile, o ~ exefile] ~ purrSrcPaths ~ opt ~ dFlags);
            if (comp.status != 0)
            {
                writeln(comp.output);
            }
            else
            {
                writeln("source: " ~ i);
                writeln("inter: " ~ dfile);
                writeln("exe: " ~ exefile);
            }
        }
        else
        {
            string cdir = getcwd;
            scope (exit)
            {
                cdir.chdir;
            }
            i.dirName.chdir;
            Dynamic retval = ctx.eval(code);
            if (echo && retval.type != Dynamic.Type.nil)
            {
                writeln(retval);
            }
        }
    }
    if (repl && (scripts.length == 0 && stmts.length == 0))
    {
        parse("", langNameDefault ~ ".repl");
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
        writeln(ret);
        writeln(e.msg);
    }
}

void main(string[] args)
{
    trymain(args);
}

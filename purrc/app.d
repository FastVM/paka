module purrc.app;

import purr.ir.repr;
import purr.ir.walk;
import purr.ir.emit;
import purr.vm;
import purr.base;
import purr.ast;
import purr.base;
import purr.dynamic;
import purr.parse;
import purr.inter;
import purr.srcloc;
import purr.fs.files;
import purr.fs.disk;
import purr.plugin.loader;
import purr.plugin.plugin;
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

enum string[string] objs()
{
    string[string] ret;
    string name;
    static foreach (libname; import("this.txt").strip.splitter(" "))
    {
        ret["libpurr_" ~ libname ~ ".o"] ~= import("libpurr_" ~ libname ~ ".o");
    }
    return ret;
}

string[] writeObjects()
{
    File file;
    string[] names;
    static foreach (name, data; objs)
    {
        names ~= name;
        file = File(name, "wb");
        file.write(data);
    }
    return names;
}

void delObjects()
{
    static foreach (name, data; objs)
    {
        std.file.remove(name);
    }
}

/// the actual main function, it does not handle errors
void domain(string[] args)
{
    string[] scripts;
    string[] langs;
    string lnd = "paka";
    string compilerArg = null;
    string dFlagsArg;
    string doOptArg = "0";
    auto info = getopt(args, "file", &scripts, "load", &langs, "lang", &lnd,
            "compiler", &compilerArg, "flags", &dFlagsArg, "opt", &doOptArg);
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
    if (scripts.length == 0)
    {
        throw new Exception("must specify an input file");
    }
    if (scripts.length > 1)
    {
        throw new Exception("must specify only one input file");
    }
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
    foreach (i; scripts)
    {
        compiler ~= writeObjects.map!(x => x).array;
        scope (exit)
        {
            delObjects;
        }
        Location code = Location(1, 1, i, i.readText);
        if (compiler == null)
        {
            throw new Exception("must specify a compiler");
        }
        Node node = code.parse;
        Walker walker = new Walker;
        BasicBlock bb = walker.bbwalk(node);
        import purrc.native : NativeBackend;

        Generator gen = new NativeBackend;
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
        string[] purrSrcPaths = ["purrc/libs/native.d"];
        string[] programs = ["purr/app.d"];
        foreach (entry; purrDirEntries)
        {
            if (!entry.isDir && entry.name.length > 2
                    && entry.name[$ - 2 .. $] == ".d" && !programs.canFind(entry.name))
            {
                purrSrcPaths ~= entry.name;
            }
        }
        string[] cmd = compiler ~ [dfile, o ~ exefile] ~ purrSrcPaths ~ opt ~ dFlags;
        // writeln(cast(string) cmd.joiner(" ").array);
        auto comp = execute(cmd);
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
}

/// the main function that handles runtime errors
// void trymain(string[] args)
// {
//     try
//     {
//         domain(args);
//     }
//     catch (Exception e)
//     {
//         size_t[] nums;
//         size_t[] times;
//         size_t ml = 0;
//         foreach (i; spans)
//         {
//             if (nums.length != 0 && nums[$ - 1] == i.first.line)
//             {
//                 times[$ - 1]++;
//             }
//             else
//             {
//                 nums ~= i.first.line;
//                 times ~= 1;
//                 ml = max(ml, i.first.line.to!string.length);
//             }
//         }
//         string ret = "error on \n";
//         foreach (i, v; nums)
//         {
//             if (i == 0)
//             {
//                 ret ~= "line";
//             }
//             else
//             {
//                 ret ~= "from";
//             }
//             foreach (j; 0 .. ml.to!string.length - v.to!string.length + 2)
//             {
//                 ret ~= " ";
//             }
//             ret ~= v.to!string;
//             if (times[i] > 2)
//             {
//                 ret ~= " (repeated: " ~ times[i].to!string ~ " times)";
//             }
//             ret ~= "\n";
//         }
//         spans.length = 0;
//         writeln(ret);
//         writeln(e.msg);
//     }
// }

void main(string[] args)
{
    domain(args);
}

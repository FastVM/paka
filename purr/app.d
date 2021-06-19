module purr.app;

import purr.io;
import purr.ir.repr;
import purr.ir.opt;
import purr.ir.walk;
import purr.srcloc;
import purr.ast.ast;
import purr.parse;
import purr.inter;
import purr.io;
import purr.ir.walk;
import std.uuid;
import std.path;
import std.array;
import std.file;
import std.json;
import std.ascii;
import std.algorithm;
import std.conv;
import std.string;
import std.getopt;
import std.datetime.stopwatch;
import core.memory;
import core.time;
import core.stdc.stdlib;
import std.process;

extern (C) __gshared string[] rt_options = [];

string dflags;
string wasmFlags = " -mtriple=wasm32-unknown-unknown-wasm -L--no-entry bin/crt.o";
string outfile = "./bin/out";
string runCommand = "";

alias Thunk = void delegate();

string drtd = import("drt.d");
string crtc = import("crt.c");

void extractRuntime()
{
    if (!"bin/drt.d".exists)
    {
        File drtf = File("bin/drt.d", "w");
        drtf.write(drtd);
        drtf.close();
    }
    if (!"bin/crt.c".exists)
    {
        File crtf = File("bin/crt.c", "w");
        crtf.write(crtc);
        crtf.close();
    }
    if (!"bin/crt.o".exists)
    {
        string cmd = "clang -Ibin bin/crt.c -o bin/crt.o --target=wasm32-undefined-undefined-wasm -c";
        auto res = executeShell(cmd);
        if (res.status != 0)
        {
            writeln(res.output);
            throw new Exception("could not build runtime");
        }
    }
}

Thunk cliCleanHandler()
{
    return {
        foreach (filename; ["bin/crt.c", "bin/drt.d", "bin/crt.o"])
        {
            if (filename.exists)
            {
                filename.remove;
            }
        }
    };
}

Thunk cliWasmHandler(string run)
{
    return {
        extractRuntime;
        runCommand = run;
        dflags ~= wasmFlags;
    };
}

Thunk cliValidateHandler(immutable string filename)
{
    return {
        string oldLang = langNameDefault;
        scope (exit)
        {
            langNameDefault = oldLang;
        }
        if (filename.endsWith(".paka"))
        {
            langNameDefault = "paka";
        }
        if (filename.endsWith(".pn"))
        {
            langNameDefault = "passerine";
        }
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        assert(eval(code).length != 0);
    };
}

Thunk cliCompileHandler(immutable string filename)
{
    return {
        string oldLang = langNameDefault;
        scope (exit)
        {
            langNameDefault = oldLang;
        }
        if (filename.endsWith(".paka"))
        {
            langNameDefault = "paka";
        }
        if (filename.endsWith(".pn"))
        {
            langNameDefault = "passerine";
        }
        SrcLoc code = SrcLoc(1, 1, filename, filename.readText);
        File output = File("bin/out.d", "w");
        output.writeln(eval(code));
        output.close();
        if (outfile.exists)
        {
            outfile.remove;
        }
        auto res = executeShell("ldc2 bin/out.d bin/drt -O -of=" ~ outfile ~ " -betterC " ~ dflags);
        if (res.status != 0)
        {
            writeln(res.output);
            throw new Exception("Compile#2 Failed");
        }
    };
}

Thunk cliParseHandler(immutable string code)
{
    return { SrcLoc loc = SrcLoc(1, 1, "__main__", code); Node res = loc.parse; };
}

Thunk cliRunHandler()
{
    return {
        if (runCommand.length == 0)
        {
            Pid pid = spawnProcess([outfile]);
            pid.wait;
        }
        else
        {
            Pid pid = spawnProcess([runCommand, outfile]);
            pid.wait;
        }
    };
}

Thunk cliLangHandler(immutable string langname)
{
    return { langNameDefault = langname; };
}

Thunk cliAstHandler()
{
    return { dumpast = !dumpast; };
}

Thunk cliIrHandler()
{
    return { dumpir = !dumpir; };
}

Thunk cliTimeHandler(Thunk next)
{
    return {
        StopWatch watch = StopWatch(AutoStart.no);
        watch.start();
        next();
        watch.stop();
        writeln(watch.peek);
    };
}

Thunk cliBenchHandler(size_t n, Thunk next)
{
    return {
        Duration all;
        foreach (_; 0 .. n)
        {
            StopWatch watch = StopWatch(AutoStart.no);
            watch.start();
            next();
            watch.stop();
            all += watch.peek;
        }
        writeln("per run: ", all / n);
    };
}

Thunk cliRepeatHandler(size_t n, Thunk next)
{
    return {
        foreach (_; 0 .. n)
        {
            next();
        }
    };
}

Thunk cliOptHandler(size_t n)
{
    return { defaultOptLevel = n; };
}

bool debugging;

Thunk cliDebugHandler()
{
    return { debugging = !debugging; };
}

void domain(string[] args)
{
    args = args[1 .. $];
    Thunk[] todo;
    langNameDefault = "paka";
    foreach_reverse (arg; args)
    {
        string[] parts = arg.split("=").array;
        string part1()
        {
            assert(parts.length != 0);
            if (parts.length == 1)
            {
                throw new Exception(parts[0] ~ " takes an argument using " ~ parts[0] ~ "=argument");
            }
            return parts[1 .. $].join("=");
        }

        bool runNow = parts[0][$ - 1] == ':';
        scope (exit)
        {
            if (runNow)
            {
                Thunk last = todo[$ - 1];
                todo.length--;
                last();
            }
        }
        if (runNow)
        {
            parts[0].length--;
        }
        switch (parts[0])
        {
        default:
            todo ~= cliRunHandler;
            todo ~= parts[0].cliCompileHandler;
            break;
        case "--time":
            todo[$ - 1] = todo[$ - 1].cliTimeHandler;
            break;
        case "--repeat":
            todo[$ - 1] = cliRepeatHandler(part1.to!size_t, todo[$ - 1]);
            break;
        case "--bench":
            todo[$ - 1] = cliBenchHandler(part1.to!size_t, todo[$ - 1]);
            break;
        case "--file":
            todo ~= cliRunHandler;
            todo ~= part1.cliCompileHandler;
            break;
        case "--parse":
            todo ~= part1.cliParseHandler;
            break;
        case "--compile":
            todo ~= part1.cliCompileHandler;
            break;
        case "--validate":
            todo ~= part1.cliValidateHandler;
            break;
        case "--run":
            todo ~= cliRunHandler;
            break;
        case "--lang":
            todo ~= part1.cliLangHandler;
            break;
        case "--opt":
            todo ~= cliOptHandler(part1.to!size_t);
            break;
        case "--ast":
            todo ~= cliAstHandler;
            break;
        case "--ir":
            todo ~= cliIrHandler;
            break;
        case "--debug":
            cliDebugHandler()();
            break;
        case "--wasm":
            cliWasmHandler(part1)();
            break;
        case "--clean":
            cliCleanHandler()();
            break;
        }
    }
    foreach_reverse (fun; todo)
    {
        fun();
    }
}

void thrown(Err)(Err e)
{
    if (debugging)
    {
        throw e;
    }
    else
    {
        writeln(e.msg);
    }
}

/// the main function that handles runtime errors
void trymain(string[] args)
{
    try
    {
        domain(args);
    }
    catch (Error e)
    {
        e.thrown;
    }
    catch (Exception e)
    {
        e.thrown;
    }
}

void main(string[] args)
{
    trymain(args);
}
